require 'test_helper'
require 'zip/filesystem'

class ZipFsFileNonmutatingTest < MiniTest::Test
  def setup
    @zipsha = Digest::SHA1.file('test/data/zipWithDirs.zip')
    @zip_file = ::Zip::File.new('test/data/zipWithDirs.zip')
  end

  def teardown
    @zip_file.close if @zip_file
    assert_equal(@zipsha, Digest::SHA1.file('test/data/zipWithDirs.zip'))
  end

  def test_umask
    assert_equal(::File.umask, @zip_file.file.umask)
    @zip_file.file.umask(0o006)
  end

  def test_exists?
    assert(!@zip_file.file.exists?('notAFile'))
    assert(@zip_file.file.exists?('file1'))
    assert(@zip_file.file.exists?('dir1'))
    assert(@zip_file.file.exists?('dir1/'))
    assert(@zip_file.file.exists?('dir1/file12'))
    assert(@zip_file.file.exist?('dir1/file12')) # notice, tests exist? alias of exists? !

    @zip_file.dir.chdir 'dir1/'
    assert(!@zip_file.file.exists?('file1'))
    assert(@zip_file.file.exists?('file12'))
  end

  def test_open_read
    block_called = false
    @zip_file.file.open('file1', 'r') do |f|
      block_called = true
      assert_equal("this is the entry 'file1' in my test archive!",
                   f.readline.chomp)
    end
    assert(block_called)

    block_called = false
    @zip_file.file.open('file1', 'rb') do |f| # test binary flag is ignored
      block_called = true
      assert_equal("this is the entry 'file1' in my test archive!",
                   f.readline.chomp)
    end
    assert(block_called)

    block_called = false
    @zip_file.dir.chdir 'dir2'
    @zip_file.file.open('file21', 'r') do |f|
      block_called = true
      assert_equal("this is the entry 'dir2/file21' in my test archive!",
                   f.readline.chomp)
    end
    assert(block_called)
    @zip_file.dir.chdir '/'

    assert_raises(Errno::ENOENT) do
      @zip_file.file.open('noSuchEntry')
    end

    begin
      is = @zip_file.file.open('file1')
      assert_equal("this is the entry 'file1' in my test archive!",
                   is.readline.chomp)
    ensure
      is.close if is
    end
  end

  def test_new
    begin
      is = @zip_file.file.new('file1')
      assert_equal("this is the entry 'file1' in my test archive!",
                   is.readline.chomp)
    ensure
      is.close if is
    end
    begin
      is = @zip_file.file.new('file1') do
        raise 'should not call block'
      end
    ensure
      is.close if is
    end
  end

  def test_symlink
    assert_raises(NotImplementedError) do
      @zip_file.file.symlink('file1', 'aSymlink')
    end
  end

  def test_size
    assert_raises(Errno::ENOENT) { @zip_file.file.size('notAFile') }
    assert_equal(72, @zip_file.file.size('file1'))
    assert_equal(0, @zip_file.file.size('dir2/dir21'))

    assert_equal(72, @zip_file.file.stat('file1').size)
    assert_equal(0, @zip_file.file.stat('dir2/dir21').size)
  end

  def test_size?
    assert_nil(@zip_file.file.size?('notAFile'))
    assert_equal(72, @zip_file.file.size?('file1'))
    assert_nil(@zip_file.file.size?('dir2/dir21'))

    assert_equal(72, @zip_file.file.stat('file1').size?)
    assert_nil(@zip_file.file.stat('dir2/dir21').size?)
  end

  def test_file?
    assert(@zip_file.file.file?('file1'))
    assert(@zip_file.file.file?('dir2/file21'))
    assert(!@zip_file.file.file?('dir1'))
    assert(!@zip_file.file.file?('dir1/dir11'))

    assert(@zip_file.file.stat('file1').file?)
    assert(@zip_file.file.stat('dir2/file21').file?)
    assert(!@zip_file.file.stat('dir1').file?)
    assert(!@zip_file.file.stat('dir1/dir11').file?)
  end

  include ExtraAssertions

  def test_dirname
    assert_forwarded(File, :dirname, 'ret_val', 'a/b/c/d') do
      @zip_file.file.dirname('a/b/c/d')
    end
  end

  def test_basename
    assert_forwarded(File, :basename, 'ret_val', 'a/b/c/d') do
      @zip_file.file.basename('a/b/c/d')
    end
  end

  def test_split
    assert_forwarded(File, :split, 'ret_val', 'a/b/c/d') do
      @zip_file.file.split('a/b/c/d')
    end
  end

  def test_join
    assert_equal('a/b/c', @zip_file.file.join('a/b', 'c'))
    assert_equal('a/b/c/d', @zip_file.file.join('a/b', 'c/d'))
    assert_equal('/c/d', @zip_file.file.join('', 'c/d'))
    assert_equal('a/b/c/d', @zip_file.file.join('a', 'b', 'c', 'd'))
  end

  def test_utime
    t_now = ::Zip::DOSTime.now
    t_bak = @zip_file.file.mtime('file1')
    @zip_file.file.utime(t_now, 'file1')
    assert_equal(t_now, @zip_file.file.mtime('file1'))
    @zip_file.file.utime(t_bak, 'file1')
    assert_equal(t_bak, @zip_file.file.mtime('file1'))
  end

  def assert_always_false(operation)
    assert(!@zip_file.file.send(operation, 'noSuchFile'))
    assert(!@zip_file.file.send(operation, 'file1'))
    assert(!@zip_file.file.send(operation, 'dir1'))
    assert(!@zip_file.file.stat('file1').send(operation))
    assert(!@zip_file.file.stat('dir1').send(operation))
  end

  def assert_true_if_entry_exists(operation)
    assert(!@zip_file.file.send(operation, 'noSuchFile'))
    assert(@zip_file.file.send(operation, 'file1'))
    assert(@zip_file.file.send(operation, 'dir1'))
    assert(@zip_file.file.stat('file1').send(operation))
    assert(@zip_file.file.stat('dir1').send(operation))
  end

  def test_pipe?
    assert_always_false(:pipe?)
  end

  def test_blockdev?
    assert_always_false(:blockdev?)
  end

  def test_symlink?
    assert_always_false(:symlink?)
  end

  def test_socket?
    assert_always_false(:socket?)
  end

  def test_chardev?
    assert_always_false(:chardev?)
  end

  def test_truncate
    assert_raises(StandardError, 'truncate not supported') do
      @zip_file.file.truncate('file1', 100)
    end
  end

  def assert_e_n_o_e_n_t(operation, args = ['NoSuchFile'])
    assert_raises(Errno::ENOENT) do
      @zip_file.file.send(operation, *args)
    end
  end

  def test_ftype
    assert_e_n_o_e_n_t(:ftype)
    assert_equal('file', @zip_file.file.ftype('file1'))
    assert_equal('directory', @zip_file.file.ftype('dir1/dir11'))
    assert_equal('directory', @zip_file.file.ftype('dir1/dir11/'))
  end

  def test_link
    assert_raises(NotImplementedError) do
      @zip_file.file.link('file1', 'someOtherString')
    end
  end

  def test_directory?
    assert(!@zip_file.file.directory?('notAFile'))
    assert(!@zip_file.file.directory?('file1'))
    assert(!@zip_file.file.directory?('dir1/file11'))
    assert(@zip_file.file.directory?('dir1'))
    assert(@zip_file.file.directory?('dir1/'))
    assert(@zip_file.file.directory?('dir2/dir21'))

    assert(!@zip_file.file.stat('file1').directory?)
    assert(!@zip_file.file.stat('dir1/file11').directory?)
    assert(@zip_file.file.stat('dir1').directory?)
    assert(@zip_file.file.stat('dir1/').directory?)
    assert(@zip_file.file.stat('dir2/dir21').directory?)
  end

  def test_chown
    assert_equal(2, @zip_file.file.chown(1, 2, 'dir1', 'file1'))
    assert_equal(1, @zip_file.file.stat('dir1').uid)
    assert_equal(2, @zip_file.file.stat('dir1').gid)
    assert_equal(2, @zip_file.file.chown(nil, nil, 'dir1', 'file1'))
  end

  def test_zero?
    assert(!@zip_file.file.zero?('notAFile'))
    assert(!@zip_file.file.zero?('file1'))
    assert(@zip_file.file.zero?('dir1'))
    block_called = false
    ::Zip::File.open('test/data/generated/5entry.zip') do |zf|
      block_called = true
      assert(zf.file.zero?('test/data/generated/empty.txt'))
    end
    assert(block_called)

    assert(!@zip_file.file.stat('file1').zero?)
    assert(@zip_file.file.stat('dir1').zero?)
    block_called = false
    ::Zip::File.open('test/data/generated/5entry.zip') do |zf|
      block_called = true
      assert(zf.file.stat('test/data/generated/empty.txt').zero?)
    end
    assert(block_called)
  end

  def test_expand_path
    ::Zip::File.open('test/data/zipWithDirs.zip') do |zf|
      assert_equal('/', zf.file.expand_path('.'))
      zf.dir.chdir 'dir1'
      assert_equal('/dir1', zf.file.expand_path('.'))
      assert_equal('/dir1/file12', zf.file.expand_path('file12'))
      assert_equal('/', zf.file.expand_path('..'))
      assert_equal('/dir2/dir21', zf.file.expand_path('../dir2/dir21'))
    end
  end

  def test_mtime
    assert_equal(::Zip::DOSTime.at(1_027_694_306),
                 @zip_file.file.mtime('dir2/file21'))
    assert_equal(::Zip::DOSTime.at(1_027_690_863),
                 @zip_file.file.mtime('dir2/dir21'))
    assert_raises(Errno::ENOENT) do
      @zip_file.file.mtime('noSuchEntry')
    end

    assert_equal(::Zip::DOSTime.at(1_027_694_306),
                 @zip_file.file.stat('dir2/file21').mtime)
    assert_equal(::Zip::DOSTime.at(1_027_690_863),
                 @zip_file.file.stat('dir2/dir21').mtime)
  end

  def test_ctime
    assert_nil(@zip_file.file.ctime('file1'))
    assert_nil(@zip_file.file.stat('file1').ctime)
  end

  def test_atime
    assert_nil(@zip_file.file.atime('file1'))
    assert_nil(@zip_file.file.stat('file1').atime)
  end

  def test_ntfs_time
    ::Zip::File.open('test/data/ntfs.zip') do |zf|
      t = ::Zip::DOSTime.at(1_410_496_497.405178)
      assert_equal(zf.file.mtime('data.txt'), t)
      assert_equal(zf.file.atime('data.txt'), t)
      assert_equal(zf.file.ctime('data.txt'), t)
    end
  end

  def test_readable?
    assert(!@zip_file.file.readable?('noSuchFile'))
    assert(@zip_file.file.readable?('file1'))
    assert(@zip_file.file.readable?('dir1'))
    assert(@zip_file.file.stat('file1').readable?)
    assert(@zip_file.file.stat('dir1').readable?)
  end

  def test_readable_real?
    assert(!@zip_file.file.readable_real?('noSuchFile'))
    assert(@zip_file.file.readable_real?('file1'))
    assert(@zip_file.file.readable_real?('dir1'))
    assert(@zip_file.file.stat('file1').readable_real?)
    assert(@zip_file.file.stat('dir1').readable_real?)
  end

  def test_writable?
    assert(!@zip_file.file.writable?('noSuchFile'))
    assert(@zip_file.file.writable?('file1'))
    assert(@zip_file.file.writable?('dir1'))
    assert(@zip_file.file.stat('file1').writable?)
    assert(@zip_file.file.stat('dir1').writable?)
  end

  def test_writable_real?
    assert(!@zip_file.file.writable_real?('noSuchFile'))
    assert(@zip_file.file.writable_real?('file1'))
    assert(@zip_file.file.writable_real?('dir1'))
    assert(@zip_file.file.stat('file1').writable_real?)
    assert(@zip_file.file.stat('dir1').writable_real?)
  end

  def test_executable?
    assert(!@zip_file.file.executable?('noSuchFile'))
    assert(!@zip_file.file.executable?('file1'))
    assert(@zip_file.file.executable?('dir1'))
    assert(!@zip_file.file.stat('file1').executable?)
    assert(@zip_file.file.stat('dir1').executable?)
  end

  def test_executable_real?
    assert(!@zip_file.file.executable_real?('noSuchFile'))
    assert(!@zip_file.file.executable_real?('file1'))
    assert(@zip_file.file.executable_real?('dir1'))
    assert(!@zip_file.file.stat('file1').executable_real?)
    assert(@zip_file.file.stat('dir1').executable_real?)
  end

  def test_owned?
    assert_true_if_entry_exists(:owned?)
  end

  def test_grpowned?
    assert_true_if_entry_exists(:grpowned?)
  end

  def test_setgid?
    assert_always_false(:setgid?)
  end

  def test_setuid?
    assert_always_false(:setgid?)
  end

  def test_sticky?
    assert_always_false(:sticky?)
  end

  def test_readlink
    assert_raises(NotImplementedError) do
      @zip_file.file.readlink('someString')
    end
  end

  def test_stat
    s = @zip_file.file.stat('file1')
    assert(s.kind_of?(File::Stat)) # It pretends
    assert_raises(Errno::ENOENT, 'No such file or directory - noSuchFile') do
      @zip_file.file.stat('noSuchFile')
    end
  end

  def test_lstat
    assert(@zip_file.file.lstat('file1').file?)
  end

  def test_pipe
    assert_raises(NotImplementedError) do
      @zip_file.file.pipe
    end
  end

  def test_foreach
    ::Zip::File.open('test/data/generated/zipWithDir.zip') do |zf|
      ref = []
      File.foreach('test/data/file1.txt') { |e| ref << e }
      index = 0

      zf.file.foreach('test/data/file1.txt') do |l|
        # Ruby replaces \n with \r\n automatically on windows
        newline = Zip::RUNNING_ON_WINDOWS ? l.gsub(/\r\n/, "\n") : l
        assert_equal(ref[index], newline)
        index = index.next
      end
      assert_equal(ref.size, index)
    end

    ::Zip::File.open('test/data/generated/zipWithDir.zip') do |zf|
      ref = []
      File.foreach('test/data/file1.txt', ' ') { |e| ref << e }
      index = 0

      zf.file.foreach('test/data/file1.txt', ' ') do |l|
        # Ruby replaces \n with \r\n automatically on windows
        newline = Zip::RUNNING_ON_WINDOWS ? l.gsub(/\r\n/, "\n") : l
        assert_equal(ref[index], newline)
        index = index.next
      end
      assert_equal(ref.size, index)
    end
  end

  def test_glob
    ::Zip::File.open('test/data/globTest.zip') do |zf|
      {
        'globTest/foo.txt' => ['globTest/foo.txt'],
        '*/foo.txt'        => ['globTest/foo.txt'],
        '**/foo.txt'       => [
          'globTest/foo.txt', 'globTest/foo/bar/baz/foo.txt'
        ],
        '*/foo/**/*.txt'   => ['globTest/foo/bar/baz/foo.txt']
      }.each do |spec, expected_results|
        results = zf.glob(spec)
        assert(results.all? { |entry| entry.kind_of? ::Zip::Entry })

        result_strings = results.map(&:to_s)
        missing_matches = expected_results - result_strings
        extra_matches = result_strings - expected_results

        assert extra_matches.empty?, "spec #{spec.inspect} has extra results #{extra_matches.inspect}"
        assert missing_matches.empty?, "spec #{spec.inspect} missing results #{missing_matches.inspect}"
      end
    end

    ::Zip::File.open('test/data/globTest.zip') do |zf|
      results = []
      zf.glob('**/foo.txt') do |match|
        results << "<#{match.class.name}: #{match}>"
      end
      assert(!results.empty?, 'block not run, or run out of context')
      assert_equal 2, results.size
      assert_operator results, :include?, '<Zip::Entry: globTest/foo.txt>'
      assert_operator results, :include?, '<Zip::Entry: globTest/foo/bar/baz/foo.txt>'
    end
  end

  def test_popen
  #   hash = {"TRAVIS_TAG"=>"", 
  #     "PATH"=>"/home/travis/build/bjfish/rubyzip/vendor/bundle/truffleruby/20.3.0-dev-dfe23de9/bin:/home/travis/.rvm/gems/truffleruby-head/bin:/home/travis/.rvm/gems/truffleruby-head@global/bin:/home/travis/.rvm/rubies/truffleruby-head/bin:/home/travis/.rvm/bin:/home/travis/bin:/home/travis/.local/bin:/usr/local/lib/jvm/openjdk11/bin:/opt/pyenv/shims:/home/travis/.phpenv/shims:/home/travis/perl5/perlbrew/bin:/home/travis/.nvm/versions/node/v8.12.0/bin:/home/travis/gopath/bin:/home/travis/.gimme/versions/go1.11.1.linux.amd64/bin:/usr/local/maven-3.6.3/bin:/usr/local/cmake-3.12.4/bin:/usr/local/clang-7.0.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/home/travis/.phpenv/bin:/opt/pyenv/bin:/home/travis/.yarn/bin", "IRBRC"=>"/home/travis/.rvm/rubies/truffleruby-head/.irbrc", "PYENV_SHELL"=>"bash", "BUNDLER_ORIG_RUBYLIB"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", 
  #     "HISTCONTROL"=>"ignoredups:ignorespace", "TRAVIS_ROOT"=>"/", "CASHER_DIR"=>"/home/travis/.casher", "TRAVIS_RUBY_VERSION"=>"truffleruby-head", "TRAVIS_PRE_CHEF_BOOTSTRAP_TIME"=>"2020-06-24T13:13:03", "TRAVIS_ALLOW_FAILURE"=>"", "TRAVIS_APT_PROXY"=>"http://build-cache.travisci.net", "BUNDLE_BIN_PATH"=>"/home/travis/.rvm/rubies/truffleruby-head/lib/gems/gems/bundler-1.17.2/exe/bundle", "TRAVIS_OS_NAME"=>"linux", "BUNDLER_ORIG_MANPATH"=>"/home/travis/.nvm/versions/node/v8.12.0/share/man:/home/travis/.rvm/rubies/ruby-2.5.3/share/man:/usr/local/cmake-3.12.4/man:/usr/local/clang-7.0.0/share/man:/usr/local/man:/usr/local/share/man:/usr/share/man:/home/travis/.rvm/man", "TRAVIS_COMMIT_MESSAGE"=>"Add debug stuff", "rvm_version"=>"1.29.10-next (master)", "TRAVIS_EVENT_TYPE"=>"push", "PWD"=>"/home/travis/build/bjfish/rubyzip", "BUNDLER_ORIG_RB_USER_INSTALL"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "TRAVIS_OSX_IMAGE"=>"", "LANGUAGE"=>"en_US.UTF-8", "COVERALLS_PARALLEL"=>"true", "NVM_CD_FLAGS"=>"", "HAS_ANTARES_THREE_LITTLE_FRONZIES_BADGE"=>"true", "PYTHON_CFLAGS"=>"-g -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security", "TRAVIS_SECURE_ENV_VARS"=>"false", "PERLBREW_SHELLRC_VERSION"=>"0.88", "PAGER"=>"cat", "ANSI_CLEAR"=>"\\033[0K", "MY_RUBY_HOME"=>"/home/travis/.rvm/rubies/truffleruby-head", "TRAVIS_INTERNAL_RUBY_REGEX"=>"^ruby-(2\\.[0-4]\\.[0-9]|1\\.9\\.3)", "TRAVIS_TEST_RESULT"=>"", "MYSQL_UNIX_PORT"=>"/var/run/mysqld/mysqld.sock", "rvm_path"=>"/home/travis/.rvm", "TRAVIS_DIST"=>"xenial", "LC_ALL"=>"en_US.UTF-8", "TRAVIS_TIMER_START_TIME"=>"1598392837785807557", "BUNDLE_GEMFILE"=>"/home/travis/build/bjfish/rubyzip/Gemfile", "TRAVIS_ENABLE_INFRA_DETECTION"=>"true", "LC_CTYPE"=>"en_US.UTF-8", "SHLVL"=>"2", "rvm_pretty_print_flag"=>"auto", "BUNDLER_ORIG_PATH"=>"/home/travis/.rvm/gems/truffleruby-head/bin:/home/travis/.rvm/gems/truffleruby-head@global/bin:/home/travis/.rvm/rubies/truffleruby-head/bin:/home/travis/.rvm/bin:/home/travis/bin:/home/travis/.local/bin:/usr/local/lib/jvm/openjdk11/bin:/opt/pyenv/shims:/home/travis/.phpenv/shims:/home/travis/perl5/perlbrew/bin:/home/travis/.nvm/versions/node/v8.12.0/bin:/home/travis/gopath/bin:/home/travis/.gimme/versions/go1.11.1.linux.amd64/bin:/usr/local/maven-3.6.3/bin:/usr/local/cmake-3.12.4/bin:/usr/local/clang-7.0.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/home/travis/.phpenv/bin:/opt/pyenv/bin:/home/travis/.yarn/bin", "BUNDLER_ORIG_GEM_PATH"=>"/home/travis/.rvm/gems/truffleruby-head:/home/travis/.rvm/gems/truffleruby-head@global", "PYTHON_CONFIGURE_OPTS"=>"--enable-unicode=ucs4 --with-wide-unicode --enable-shared --enable-ipv6 --enable-loadable-sqlite-extensions --with-computed-gotos", "HISTSIZE"=>"1000", "JAVA_HOME"=>"/usr/local/lib/jvm/openjdk11", "TERM"=>"xterm", "TRAVIS_INIT"=>"systemd", "TRAVIS_JOB_NUMBER"=>"14.1", "XDG_SESSION_ID"=>"2", "ANSI_RED"=>"\\033[31;1m", "BUNDLER_ORIG_BUNDLE_BIN_PATH"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "MERB_ENV"=>"test", "RACK_ENV"=>"test", "BUNDLER_ORIG_RUBYOPT"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "NVM_INC"=>"/home/travis/.nvm/versions/node/v8.12.0/include/node", "TRAVIS_UID"=>"2000", "TRAVIS_LANGUAGE"=>"ruby", "BUNDLER_ORIG_BUNDLER_ORIG_MANPATH"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "TRAVIS_BRANCH"=>"master", "TRAVIS"=>"true", "CI"=>"true", "SSH_TTY"=>"/dev/pts/0", "SSH_CLIENT"=>"10.52.6.36 38118 22", "PERLBREW_HOME"=>"/home/travis/.perlbrew", "TRAVIS_STACK_NAME"=>"sardonyx", "TRAVIS_STACK_TIMESTAMP"=>"2020-06-24 13:13:18 UTC", "TRAVIS_COMMIT_RANGE"=>"03de63c7463a...34c4109c9264", "TRAVIS_STACK_JOB_BOARD_REGISTER"=>"/.job-board-register.yml", "TRAVIS_PULL_REQUEST_SHA"=>"", "GOROOT"=>"/home/travis/.gimme/versions/go1.11.1.linux.amd64", "TRAVIS_COMMIT"=>"34c4109c92642d870e54e0a352919712faa808c6", "TRAVIS_REPO_SLUG"=>"bjfish/rubyzip", "SSH_CONNECTION"=>"10.52.6.36 38118 10.20.0.172 22", "GEM_PATH"=>"", "TRAVIS_BUILD_STAGE_NAME"=>"", "TRAVIS_HOME"=>"/home/travis", "PERLBREW_ROOT"=>"/home/travis/perl5/perlbrew", "NVM_BIN"=>"/home/travis/.nvm/versions/node/v8.12.0/bin", "TRAVIS_ARCH"=>"amd64", "BUNDLER_ORIG_GEM_HOME"=>"/home/travis/.rvm/gems/truffleruby-head", "XDG_DATA_DIRS"=>"/usr/local/share:/usr/share:/var/lib/snapd/desktop", "TZ"=>"UTC", "TRAVIS_JOB_ID"=>"721153050", "BUNDLER_ORIG_BUNDLE_GEMFILE"=>"/home/travis/build/bjfish/rubyzip/Gemfile", "RBENV_SHELL"=>"bash", "TRAVIS_PULL_REQUEST_BRANCH"=>"", "TRAVIS_SUDO"=>"true", "PS4"=>"+", "TRAVIS_BUILD_WEB_URL"=>"https://travis-ci.org/bjfish/rubyzip/builds/721153049", "MAIL"=>"/var/mail/travis", "TRAVIS_STACK_FEATURES"=>"basic couchdb disabled-ipv6 docker docker-compose elasticsearch firefox go-toolchain google-chrome jdk memcached mongodb mysql nodejs_interpreter perl_interpreter perlbrew phantomjs postgresql python_interpreter redis ruby_interpreter sqlite xserver", "LOGNAME"=>"travis", "GIT_ASKPASS"=>"echo", "TRAVIS_TIMER_ID"=>"0943e53b", "TRAVIS_CMD"=>"bundle exec rake", "TRAVIS_CPU_ARCH"=>"amd64", "RAILS_ENV"=>"test", "SHELL"=>"/bin/bash", "COMPOSER_NO_INTERACTION"=>"1", "TRAVIS_TMPDIR"=>"/tmp/tmp.ZWB7A9Oqgw", "PYENV_ROOT"=>"/opt/pyenv", "GOPATH"=>"/home/travis/gopath", "GEM_HOME"=>"/home/travis/build/bjfish/rubyzip/vendor/bundle/truffleruby/20.3.0-dev-dfe23de9", "TRAVIS_STACK_NODE_ATTRIBUTES"=>"/.node-attributes.yml", "CONTINUOUS_INTEGRATION"=>"true", "RUBY_VERSION"=>"truffleruby-head", "DEBIAN_FRONTEND"=>"noninteractive", "ANSI_GREEN"=>"\\033[32;1m", "BUNDLER_VERSION"=>"1.17.2", "TRAVIS_BUILD_NUMBER"=>"14", "BUNDLER_ORIG_BUNDLER_VERSION"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "TRAVIS_INFRA"=>"unknown", "MANPATH"=>"/home/travis/.nvm/versions/node/v8.12.0/share/man:/home/travis/.rvm/rubies/ruby-2.5.3/share/man:/usr/local/cmake-3.12.4/man:/usr/local/clang-7.0.0/share/man:/usr/local/man:/usr/local/share/man:/usr/share/man:/home/travis/.rvm/man", "HAS_JOSH_K_SEAL_OF_APPROVAL"=>"true", "rvm_bin_path"=>"/home/travis/.rvm/bin", "TRAVIS_STACK_LANGUAGES"=>"__sardonyx__ c c++ clojure cplusplus cpp default generic go groovy java node_js php pure_java python ruby scala", "TRAVIS_JOB_NAME"=>"", "TRAVIS_BUILD_ID"=>"721153049", "rvm_prefix"=>"/home/travis", "LANG"=>"en_US.UTF-8", "TRAVIS_PULL_REQUEST"=>"false", "HISTFILESIZE"=>"2000", "install_flag"=>"1", "ANSI_RESET"=>"\\033[0m", "RUBYLIB"=>"", "APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE"=>"1", "JRUBY_OPTS"=>"--debug", "TRAVIS_PULL_REQUEST_SLUG"=>"", "NVM_DIR"=>"/home/travis/.nvm", "ANSI_YELLOW"=>"\\033[33;1m", "TRAVIS_BUILD_DIR"=>"/home/travis/build/bjfish/rubyzip", "USER"=>"travis", "TRAVIS_APP_HOST"=>"build.travis-ci.org", "RUBYOPT"=>"-rbundler/setup", "TRAVIS_JOB_WEB_URL"=>"https://travis-ci.org/bjfish/rubyzip/jobs/721153050", "XDG_RUNTIME_DIR"=>"/run/user/2000", "HOME"=>"/home/travis"}  
  #   puts "envstart====="
  #  # env = ENV.to_hash.dup
  #   p ENV.to_hash
    # minutes = 10 
    # puts "sleeping #{minutes} minutes"
    # sleep (minutes * 60)
    # puts "OPENFILES"
    # ObjectSpace.each_object(File) do |f|
    #   puts "%s: %d" % [f.path, f.fileno] unless f.closed?
    # end
    # puts "envend===="
    #ENV = hash
    if Zip::RUNNING_ON_WINDOWS
      # This is pretty much projectile vomit but it allows the test to be
      # run on windows also
      system_dir = ::File.popen('dir', &:read).gsub(/Dir\(s\).*$/, '')
      zipfile_dir = @zip_file.file.popen('dir', &:read).gsub(/Dir\(s\).*$/, '')
      assert_equal(system_dir, zipfile_dir)
    else
    #  begin
     b  = ::File.popen('ls', &:read) 
     a = @zip_file.file.popen('ls', &:read)


      assert_equal(b, a)
    #  ensure
      # ENV = env
    #  end
    end
  end

  # Can be added later
  #  def test_select
  #    fail "implement test"
  #  end

  def test_readlines
    ::Zip::File.open('test/data/generated/zipWithDir.zip') do |zf|
      orig_file = ::File.readlines('test/data/file1.txt')
      zip_file = zf.file.readlines('test/data/file1.txt')

      # Ruby replaces \n with \r\n automatically on windows
      zip_file.each { |l| l.gsub!(/\r\n/, "\n") } if Zip::RUNNING_ON_WINDOWS

      assert_equal(orig_file, zip_file)
    end
  end

  def test_read
    ::Zip::File.open('test/data/generated/zipWithDir.zip') do |zf|
      orig_file = ::File.read('test/data/file1.txt')

      # Ruby replaces \n with \r\n automatically on windows
      zip_file = if Zip::RUNNING_ON_WINDOWS
                   zf.file.read('test/data/file1.txt').gsub(/\r\n/, "\n")
                 else
                   zf.file.read('test/data/file1.txt')
                 end
      assert_equal(orig_file, zip_file)
    end
  end
end
