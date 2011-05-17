require File.dirname(__FILE__) + "/helper"

class RequireTest < Test::Unit::TestCase

  def setup
    FakeFS.activate!
  end

  def teardown
    FakeFS::Require.deactivate!
    FakeFS::Require.clear
    
    FakeFS::FileSystem.clear
    FakeFS.deactivate!
  end
  
  def test_fakes_require
    FakeFS::Require.activate!
    
    # require a file
    code = <<-EOS
      module FakeFSTestRequire1
      end
    EOS
    File.open "fake_fs_test_require1.rb", "w" do |f|
      f.write code
    end
    require "fake_fs_test_require1.rb"
    assert ::FakeFSTestRequire1
    
    # require a file that doesn't exist
    assert_raise LoadError do
      require "foo"
    end
    
    # always append .rb if the filename doesn't end with it
    code = <<-EOS
      module FakeFSTestRequire2_WithDotRb
      end
    EOS
    File.open "fake_fs_test_require2.rb", "w" do |f|
      f.write code
    end
    code = <<-EOS
      module FakeFSTestRequire2_WithoutDotRb
      end
    EOS
    File.open "fake_fs_test_require2", "w" do |f|
      f.write code
    end
    require "fake_fs_test_require2"
    assert ::FakeFSTestRequire2_WithDotRb
    
    # remember which files have been loaded
    code = <<-EOS
      module FakeFSTestRequire3
      end
    EOS
    File.open "fake_fs_test_require3.rb", "w" do |f|
      f.write code
    end
    require "fake_fs_test_require3"
    assert_equal "fake_fs_test_require3.rb", $".last
    assert !require("fake_fs_test_require3")
    
    # properly deactivate
    FakeFS::Require.deactivate!
    assert_raise LoadError do
      require "bar"
    end
  end
  
  def test_fakes_require_with_fallback
    FakeFS::Require.activate! :fallback => true
    
    # load a file that's in the real (= non-faked) load path
    begin
      dir = RealDir.tmpdir + "/" + rand.to_s[2..-1]
      RealDir.mkdir dir
      
      $LOAD_PATH.unshift dir
      
      code = <<-EOS
        module FakeFSTestRequireWithFallback
        end
      EOS
      RealFile.open dir + "/fake_fs_test_require_with_fallback.rb", "w" do |f|
        f.write code
      end
      
      require "fake_fs_test_require_with_fallback.rb"
      assert FakeFSTestRequireWithFallback
    ensure
      RealFile.delete dir + "/fake_fs_test_require_with_fallback.rb"
      RealDir.delete dir
      $LOAD_PATH.delete dir
    end
    
    # load a file that exists neither in fakefs nor in the real load path
    assert_raise LoadError do
      require "fake_fs_test_require_with_fooback.rb"
    end
    
    # load a file from a gem
    require "rack/static.rb"
    assert ::Rack::Static
    assert_raise LoadError do
      require "rack/is_great"
    end
    
    # turned off fallback
    FakeFS::Require.opts[:fallback] = false
    assert_raise LoadError do
      require "rack/mime"
    end
  end
  
  def test_fakes_autoload
    FakeFS::Require.activate! :autoload => true
    
    code = <<-EOS
      module FakeFSTestAutoload
        autoload :Foo, "fake_fs_test_autoload/foo"
        autoload :Bar, "fake_fs_test_autoload/bar"
      end
    EOS
    File.open "fake_fs_test_autoload.rb", "w" do |f|
      f.write code
    end
    code = <<-EOS
      module FakeFSTestAutoload
        module Foo
        end
      end
    EOS
    File.open "fake_fs_test_autoload/foo.rb", "w" do |f|
      f.write code
    end
    
    require "fake_fs_test_autoload"
    
    # autoload
    assert FakeFSTestAutoload::Foo
    
    # autoload with non-existing path
    assert_raise LoadError do
      FakeFSTestAutoload::Bar
    end
    
    # no autoload
    assert_raise NameError do
      FakeFSTestAutoload::Baz
    end
  end
  
  def test_fakes_load
    FakeFS::Require.activate! :load => true
    
    # loads a file
    File.open "fake_fs_test_load.rb", "w" do |f|
      f.write <<-CODE
        module FakeFSTestLoad
          @count ||= 0
          @count += 1
          def self.count; return @count; end
        end
      CODE
    end
    load "fake_fs_test_load.rb"
    assert_equal 1, FakeFSTestLoad.count
    
    # loads the file twice
    load "fake_fs_test_load.rb"
    assert_equal 2, FakeFSTestLoad.count
    
    # doesn't append .rb
    assert_raise(LoadError) { load "fake_fs_test_load/asd.rb" }
    
    # falls back to the original #load
    fn = "fake_fs_test_load2.rb"
    FakeFS::Require.opts[:fallback] = true
    self.expects(:fakefs_original_load).with(fn, false).returns(true)
    load fn
    
    # executes the file within an anonymous module
    File.open "fake_fs_test_load3.rb", "w" do |f|
      f.write <<-CODE
        module FakeFSTestLoad3
        end
      CODE
    end
    load "fake_fs_test_load3.rb", true
    assert_raise(NameError) { FakeFSTestLoad3 }
  end

end
