use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Main;
use JSON::PS;

my $machine = {"image" => "ubuntu-2004:202101-01"};
my $circleci_version = "2.1";

for (
  [{} => {}],
  [{"#abc" => 1} => {}],

  [{meta => {}} => {}, 'meta empty'],

  [{travisci => {}} => {'.travis.yml' => {json => {
  }}}],
  [{travisci => {pmbp => 'latest'}} => {'.travis.yml' => {json => {
    git => {submodules => \0},
    language => 'perl',
    perl => ['5.32'],
    before_install => 'true',
    install => 'make test-deps',
    script => 'make test',
  }}}],
  [{travisci => {pmbp => '5.8+'}} => {'.travis.yml' => {json => {
    git => {submodules => \0},
    language => 'perl',
    perl => ['5.32', '5.14', '5.8'],
    before_install => 'true',
    install => 'make test-deps',
    script => 'make test',
  }}}],
  [{travisci => {pmbp => '5.10+'}} => {'.travis.yml' => {json => {
    git => {submodules => \0},
    language => 'perl',
    perl => ['5.32', '5.14', '5.10'],
    before_install => 'true',
    install => 'make test-deps',
    script => 'make test',
  }}}],
  [{travisci => {pmbp => '5.12+'}} => {'.travis.yml' => {json => {
    git => {submodules => \0},
    language => 'perl',
    perl => ['5.32', '5.14', '5.12'],
    before_install => 'true',
    install => 'make test-deps',
    script => 'make test',
  }}}],
  [{travisci => {pmbp => '5.14+'}} => {'.travis.yml' => {json => {
    git => {submodules => \0},
    language => 'perl',
    perl => ['5.32', '5.14'],
    before_install => 'true',
    install => 'make test-deps',
    script => 'make test',
  }}}],
  [{travisci => {pmbp => 1}} => {'.travis.yml' => {json => {
    git => {submodules => \0},
    language => 'perl',
    perl => ['5.32', '5.14', '5.8'],
    before_install => 'true',
    install => 'make test-deps',
    script => 'make test',
  }}}],
  [{travisci => {notifications => 'suika'}} => {'.travis.yml' => {json => {
    notifications => {
      email => ['wakaba@suikawiki.org'],
      irc => {channels => ['ircs://irc.suikawiki.org:6697#mechanize'], use_notice => \1},
    },
  }}}],
  [{travisci => {merger => 1}} => {'.travis.yml' => {json => {
    env => {global => {secure => "ab xxx 314444\n"}},
    jobs => {include => [
      {stage => 'test'},
      {stage => 'merge',
       before_install => "true",
       install => "true",
       script => 'curl -f https://gist.githubusercontent.com/wakaba/ab553f86cd017e0cb28c6dbb5364b009/raw/travis-merge-job.pl | perl'},
    ]},
  }}}],
  [{travisci => {empty => 1}} => {'.travis.yml' => {json => {
    git => {submodules => \0},
    before_install => 'true',
    install => 'true',
    script => 'true',
  }}}],

  [{circleci => {}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}, 'circleci empty'],
  [{circleci => {'docker-build' => 'abc/def'}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker build -t abc/def .'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {run => {command => 'mkdir -p .ciconfigtemp/dockerimages/abc/'}},
        {run => {command => 'docker save -o .ciconfigtemp/dockerimages/abc/def.tar abc/def'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/abc/def.tar'}},
        {deploy => {command => 'docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS || docker login -u $DOCKER_USER -p $DOCKER_PASS'}},
        {deploy => {command => 'docker push abc/def'}},
        {deploy => {command => 'curl -sSf $BWALLER_URL | BWALL_GROUP=docker BWALL_NAME=abc/def bash'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {'deploy_master' => {filters => {branches => {only => ['master']}},
                           requires => ['build'],
                           context => ['deploy-context']}},
    ]}},
  }}}, 'circleci docker-build basic 2'],
  [{circleci => {'docker-build' => 'xyz/abc/def'}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker build -t xyz/abc/def .'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {run => {command => 'mkdir -p .ciconfigtemp/dockerimages/xyz/abc/'}},
        {run => {command => 'docker save -o .ciconfigtemp/dockerimages/xyz/abc/def.tar xyz/abc/def'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/xyz/abc/def.tar'}},
        {deploy => {command => 'docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS xyz || docker login -u $DOCKER_USER -p $DOCKER_PASS xyz'}},
        {deploy => {command => 'docker push xyz/abc/def'}},
        {deploy => {command => 'curl -sSf $BWALLER_URL | BWALL_GROUP=docker BWALL_NAME=xyz/abc/def bash'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {'deploy_master' => {filters => {branches => {only => ['master']}},
                           requires => ['build'],
                           context => ['deploy-context']}},
    ]}},
  }}}, 'circleci docker-build basic 3'],
  [{circleci => {
    'docker-build' => 'xyz/abc/def',
    build_generated_files => [],
    tests => ['test1'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker build -t xyz/abc/def .'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {run => {command => 'mkdir -p .ciconfigtemp/dockerimages/xyz/abc/'}},
        {run => {command => 'docker save -o .ciconfigtemp/dockerimages/xyz/abc/def.tar xyz/abc/def'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, test => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/xyz/abc/def.tar'}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test1'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test'}},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/xyz/abc/def.tar'}},
        {deploy => {command => 'docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS xyz || docker login -u $DOCKER_USER -p $DOCKER_PASS xyz'}},
        {deploy => {command => 'docker push xyz/abc/def'}},
        {deploy => {command => 'curl -sSf $BWALLER_URL | BWALL_GROUP=docker BWALL_NAME=xyz/abc/def bash'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {test => {requires => ['build']}},
      {'deploy_master' => {filters => {branches => {only => ['master']}},
                           requires => ['build', 'test'],
                           context => ['deploy-context']}},
    ]}},
  }}}, 'build jobs / docker'],
  [{circleci => {
    'docker-build' => {expression => 'xyz/$ABC/def:$CIRCLE_SHA1'},
    build_generated_files => [],
    tests => ['test1'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker build -t xyz/$ABC/def:$CIRCLE_SHA1 .'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {run => {command => 'mkdir -p .ciconfigtemp/dockerimages/xyz/$ABC/def/'}},
        {run => {command => 'docker save -o .ciconfigtemp/dockerimages/xyz/$ABC/def/$CIRCLE_SHA1.tar xyz/$ABC/def:$CIRCLE_SHA1'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, test => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/xyz/$ABC/def/$CIRCLE_SHA1.tar'}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test1'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test'}},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/xyz/$ABC/def/$CIRCLE_SHA1.tar'}},
        {deploy => {command => 'docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS xyz || docker login -u $DOCKER_USER -p $DOCKER_PASS xyz'}},
        {deploy => {command => 'docker push xyz/$ABC/def:$CIRCLE_SHA1'}},
        {deploy => {command => 'curl -sSf $BWALLER_URL | BWALL_GROUP=docker BWALL_NAME=xyz/*/def:* bash'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {test => {requires => ['build']}},
      {'deploy_master' => {filters => {branches => {only => ['master']}},
                           requires => ['build', 'test'],
                           context => ['deploy-context']}},
    ]}},
  }}}, 'build jobs / docker, expression'],
  [{circleci => {
    'docker-build' => {expression => 'xyz/$ABC/def:$CIRCLE_SHA1',
                       no_push => 1},
    build_generated_files => [],
    tests => ['test1'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker build -t xyz/$ABC/def:$CIRCLE_SHA1 .'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {run => {command => 'mkdir -p .ciconfigtemp/dockerimages/xyz/$ABC/def/'}},
        {run => {command => 'docker save -o .ciconfigtemp/dockerimages/xyz/$ABC/def/$CIRCLE_SHA1.tar xyz/$ABC/def:$CIRCLE_SHA1'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, test => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/xyz/$ABC/def/$CIRCLE_SHA1.tar'}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test1'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {test => {requires => ['build']}},
    ]}},
  }}}, 'build jobs / docker, expression, no push'],
  [{circleci => {
    'docker-build' => 'xyz/abc/def',
    build_generated_files => [],
    pmbp => 1,
    build => ["echo 2"],
    tests => ["echo 1"],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'echo 2'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker build -t xyz/abc/def .'}},
        {run => {command => 'make test-deps'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {run => {command => 'mkdir -p .ciconfigtemp/dockerimages/xyz/abc/'}},
        {run => {command => 'docker save -o .ciconfigtemp/dockerimages/xyz/abc/def.tar xyz/abc/def'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, test => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/xyz/abc/def.tar'}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'echo 1'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test'}},
      ],
    }, 'test-pmbp' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-pmbp'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/xyz/abc/def.tar'}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'make test'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-pmbp'}},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/xyz/abc/def.tar'}},
        {deploy => {command => 'docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS xyz || docker login -u $DOCKER_USER -p $DOCKER_PASS xyz'}},
        {deploy => {command => 'docker push xyz/abc/def'}},
        {deploy => {command => 'curl -sSf $BWALLER_URL | BWALL_GROUP=docker BWALL_NAME=xyz/abc/def bash'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {'test-pmbp' => {requires => ['build']}},
      {test => {requires => ['build']}},
      {'deploy_master' => {filters => {branches => {only => ['master']}},
                           requires => ['build', 'test-pmbp', 'test'],
                           context => ['deploy-context']}},
    ]}},
  }}}, 'build jobs / docker with tests'],
  [{circleci => {'docker-build' => 'abc/def',
                 context => 'foo-bar'}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker build -t abc/def .'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {run => {command => 'mkdir -p .ciconfigtemp/dockerimages/abc/'}},
        {run => {command => 'docker save -o .ciconfigtemp/dockerimages/abc/def.tar abc/def'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'docker load -i .ciconfigtemp/dockerimages/abc/def.tar'}},
        {deploy => {command => 'docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS || docker login -u $DOCKER_USER -p $DOCKER_PASS'}},
        {deploy => {command => 'docker push abc/def'}},
        {deploy => {command => 'curl -sSf $BWALLER_URL | BWALL_GROUP=docker BWALL_NAME=abc/def bash'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {'deploy_master' => {filters => {branches => {only => ['master']}},
                           requires => ['build'],
                           context => ['deploy-context', 'foo-bar']}},
    ]}},
  }}}, 'circleci docker-build with context'],
  [{circleci => {required_docker_images => ['a/b', 'a/b/c']}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker pull a/b && docker pull a/b/c',
                 background => \1}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}, 'required_docker_images build'],
  [{circleci => {
    required_docker_images => ['a/b', 'a/b/c'],
    build_generated_files => [],
    tests => {t1 => ['test1'], t2 => ['test2']},
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker pull a/b && docker pull a/b/c',
                 background => \1}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, 'test-t1' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t1'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker pull a/b && docker pull a/b/c',
                 background => \1}},
        {run => {command => 'test1'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t1'}},
      ],
    }, 'test-t2' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t2'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker pull a/b && docker pull a/b/c',
                 background => \1}},
        {run => {command => 'test2'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t2'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {'test-t1' => {requires => ['build']}},
      {'test-t2' => {requires => ['build']}},
    ]}},
  }}}, 'required_docker_images build with tests'],
  [{circleci => {heroku => 1}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 
      'git config --global user.email "temp@circleci.test"' . "\x0A" .
      'git config --global user.name "CircleCI"'
        }},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'git checkout --orphan herokucommit && git commit -m "Heroku base commit"' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'make create-commit-for-heroku' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'git push git@heroku.com:$HEROKU_APP_NAME.git +`git rev-parse HEAD`:refs/heads/master' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {heroku => {
    app_name => 'abcdef',
  }}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 
      'git config --global user.email "temp@circleci.test"' . "\x0A" .
      'git config --global user.name "CircleCI"'
        }},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'git checkout --orphan herokucommit && git commit -m "Heroku base commit"' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'make create-commit-for-heroku' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'git push git@heroku.com:abcdef.git +`git rev-parse HEAD`:refs/heads/master' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {heroku => {prepare => [
    'abc', './foo bar',
  ]}}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 
      'git config --global user.email "temp@circleci.test"' . "\x0A" .
      'git config --global user.name "CircleCI"'
        }},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'git checkout --orphan herokucommit && git commit -m "Heroku base commit"' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'abc' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . './foo bar' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'make create-commit-for-heroku' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'git push git@heroku.com:$HEROKU_APP_NAME.git +`git rev-parse HEAD`:refs/heads/master' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {heroku => {pushed => [
    'abc', './foo bar',
  ]}}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 
      'git config --global user.email "temp@circleci.test"' . "\x0A" .
      'git config --global user.name "CircleCI"'
        }},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'git checkout --orphan herokucommit && git commit -m "Heroku base commit"' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'make create-commit-for-heroku' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'git push git@heroku.com:$HEROKU_APP_NAME.git +`git rev-parse HEAD`:refs/heads/master' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'abc' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . './foo bar' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {
    heroku => 1,
    build_generated_files => [],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 
      'git config --global user.email "temp@circleci.test"' . "\x0A" .
      'git config --global user.name "CircleCI"'
        }},
        {deploy => {command => 'git checkout --orphan herokucommit && git commit -m "Heroku base commit"'}},
        {deploy => {command => 'make create-commit-for-heroku-circleci'}},
        {deploy => {command => 'git push git@heroku.com:$HEROKU_APP_NAME.git +`git rev-parse HEAD`:refs/heads/master'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {'deploy_master' => {filters => {branches => {only => ['master']}},
                           requires => ['build'],
                           context => ['deploy-context']}},
    ]}},
  }}}, 'empty build_generated_files'],
  [{circleci => {
    heroku => 1,
    build_generated_files => ['foo', 'bar'],
    tests => ['test2'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp', 'foo', 'bar'],
        }},
      ],
    }, test => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test2'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test'}},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 
      'git config --global user.email "temp@circleci.test"' . "\x0A" .
      'git config --global user.name "CircleCI"'
        }},
        {deploy => {command => 'git checkout --orphan herokucommit && git commit -m "Heroku base commit"'}},
        {deploy => {command => 'make create-commit-for-heroku-circleci'}},
        {deploy => {command => 'git push git@heroku.com:$HEROKU_APP_NAME.git +`git rev-parse HEAD`:refs/heads/master'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {test => {requires => ['build']}},
      {'deploy_master' => {filters => {branches => {only => ['master']}},
                           requires => ['build', 'test'],
                           context => ['deploy-context']}},
    ]}},
  }}}],
  [{circleci => {
    heroku => 1,
    build_generated_files => ['foo', 'bar'],
    build_generated_pmbp => 1,
    tests => ['test3'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp', 'foo', 'bar',
                      qw(deps local perl prove plackup lserver local-server rev)],
        }},
      ],
    }, test => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test3'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test'}},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 
      'git config --global user.email "temp@circleci.test"' . "\x0A" .
      'git config --global user.name "CircleCI"'
        }},
        {deploy => {command => 'git checkout --orphan herokucommit && git commit -m "Heroku base commit"'}},
        {deploy => {command => 'make create-commit-for-heroku-circleci'}},
        {deploy => {command => 'git push git@heroku.com:$HEROKU_APP_NAME.git +`git rev-parse HEAD`:refs/heads/master'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {test => {requires => ['build']}},
      {'deploy_master' => {filters => {branches => {only => ['master']}},
                           requires => ['build', 'test'],
                           context => ['deploy-context']}},
    ]}},
  }}}],
  [{circleci => {
    build_generated_files => ['foo', 'bar'],
    tests => {
      t1 => ['test3'],
      t2 => ['test4'],
    },
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp', 'foo', 'bar'],
        }},
      ],
    }, 'test-t1' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t1'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test3'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t1'}},
      ],
    }, 'test-t2' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t2'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test4'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t2'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {'test-t1' => {requires => ['build']}},
      {'test-t2' => {requires => ['build']}},
    ]}},
  }}}, 'Multiple test steps'],
  [{circleci => {
    build_generated_files => ['foo', 'bar'],
    tests => {
      t1 => ['test3'],
      t2 => ['test4'],
    },
    make_deploy_branches => ['master'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp', 'foo', 'bar'],
        }},
      ],
    }, 'test-t1' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t1'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test3'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t1'}},
      ],
    }, 'test-t2' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t2'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test4'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t2'}},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'make deploy-master'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {'test-t1' => {requires => ['build']}},
      {'test-t2' => {requires => ['build']}},
      {deploy_master => {requires => ['build', 'test-t1', 'test-t2'],
                         filters => {branches => {only => ['master']}},
                         context => ['deploy-context']}},
    ]}},
  }}}, 'Multiple test steps with deploy'],
  [{circleci => {
    build_generated_files => ['foo', 'bar'],
    tests => {
      t1 => ['test3'],
      t2 => ['test4'],
    },
    make_deploy_branches => ['master', {name => 'devel', buildless => 1}],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp', 'foo', 'bar'],
        }},
      ],
    }, 'test-t1' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t1'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test3'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t1'}},
      ],
    }, 'test-t2' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t2'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test4'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t2'}},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'make deploy-master'}},
      ],
    }, soon_deploy_devel => {
      machine => $machine,
      steps => [
        'checkout',
        {deploy => {command => 'make deploy-devel'}},
      ],
    }, before_tests => {
      machine => $machine,
      steps => [{run => {command => 'true'}}],
    }},
    workflows => {version => 2, build => {jobs => [
      {soon_deploy_devel => {filters => {branches => {only => ['devel']}},
                             context => ['deploy-context']}},
      {'build'=>{}},
      {before_tests => {requires => ['build']}},
      {'test-t1' => {requires => ['build', 'before_tests']}},
      {'test-t2' => {requires => ['build', 'before_tests']}},
      {deploy_master => {requires => ['build', 'test-t1', 'test-t2'],
                         filters => {branches => {only => ['master']}},
                         context => ['deploy-context']}},
    ]}},
  }}}, 'Multiple test steps with build-less deploy'],
  [{circleci => {
    build_generated_files => ['foo', 'bar'],
    tests => {
      t1 => ['test3'],
      t2 => ['test4'],
    },
    make_deploy_branches => ['master', {name => 'devel', testless => 1}],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp', 'foo', 'bar'],
        }},
      ],
    }, 'test-t1' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t1'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test3'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t1'}},
      ],
    }, 'test-t2' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t2'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test4'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t2'}},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'make deploy-master'}},
      ],
    }, early_deploy_devel => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'make deploy-devel'}},
      ],
    }, before_tests => {
      machine => $machine,
      steps => [{run => {command => 'true'}}],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {early_deploy_devel => {requires => ['build'],
                              filters => {branches => {only => ['devel']}},
                              context => ['deploy-context']}},
      {before_tests => {requires => ['build']}},
      {'test-t1' => {requires => ['build', 'before_tests']}},
      {'test-t2' => {requires => ['build', 'before_tests']}},
      {deploy_master => {requires => ['build', 'test-t1', 'test-t2'],
                         filters => {branches => {only => ['master']}},
                         context => ['deploy-context']}},
    ]}},
  }}}, 'Multiple test steps with test-less deploy'],
  [{circleci => {
    build_generated_files => ['foo', 'bar'],
    tests => {
      t1 => ['test3'],
      t2 => ['test4'],
    },
    make_deploy_branches => [{name => 'master', awscli => 1},
                             {name => 'devel', testless => 1,
                              awscli => 1}],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp', 'foo', 'bar'],
        }},
      ],
    }, 'test-t1' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t1'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test3'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t1'}},
      ],
    }, 'test-t2' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t2'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test4'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t2'}},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command =>
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version"
               }},
        {deploy => {command => 'make deploy-master'}},
      ],
    }, early_deploy_devel => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command =>
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version"
               }},
        {deploy => {command => 'make deploy-devel'}},
      ],
    }, before_tests => {
      machine => $machine,
      steps => [{run => {command => 'true'}}],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {early_deploy_devel => {requires => ['build'],
                              filters => {branches => {only => ['devel']}},
                              context => ['deploy-context']}},
      {before_tests => {requires => ['build']}},
      {'test-t1' => {requires => ['build', 'before_tests']}},
      {'test-t2' => {requires => ['build', 'before_tests']}},
      {deploy_master => {requires => ['build', 'test-t1', 'test-t2'],
                         filters => {branches => {only => ['master']}},
                         context => ['deploy-context']}},
    ]}},
  }}}, 'Multiple test steps with test-less deploy and awscli'],
  [{circleci => {deploy => ['true', 'false']}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'true' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'false' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}, 'deploy commands'],
  [{circleci => {
    deploy => ['true', 'false'],
    build_generated_files => [],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'true'}},
        {deploy => {command => 'false'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {deploy_master => {requires => ['build'],
                         filters => {branches => {only => ['master']}},
                         context => ['deploy-context']}},
    ]}},
  }}}, 'deploy commands jobs'],
  [{circleci => {deploy => {
    branch => q{oge"'\\x-},
    commands => ['true', 'false'],
  }}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'oge"\\'\\\\x-' ]; then} . "\x0Atrue\x0A" . 'true' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'oge"\\'\\\\x-' ]; then} . "\x0Atrue\x0A" . 'false' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {
    make_deploy_branches => ['master', 'staging'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'make deploy-master' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'staging' ]; then} . "\x0Atrue\x0A" . 'make deploy-staging' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {
    make_deploy_branches => ['master', 'staging'],
    build_generated_pmbp => 1,
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp',
                      qw(deps local perl prove plackup lserver local-server rev)],
        }},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'make deploy-master'}},
      ],
    }, deploy_staging => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'make deploy-staging'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {deploy_master => {requires => ['build'],
                         filters => {branches => {only => ['master']}},
                         context => ['deploy-context']}},
      {deploy_staging => {requires => ['build'],
                          filters => {branches => {only => ['staging']}},
                          context => ['deploy-context']}},
    ]}},
  }}}, 'make_deploy jobs'],
  [{circleci => {merger => 1}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }, deploy_staging => {
      machine => $machine,
      steps => [
        'checkout',
        {deploy => {command => "git fetch --unshallow origin master || git fetch origin master\x0Agit checkout master || git checkout -b master origin/master\x0A".'git merge -m "auto-merge $CIRCLE_BRANCH ($CIRCLE_SHA1) into master" $CIRCLE_SHA1'."\x0Agit push origin master\x0A" .
                        'curl -sSf $BWALLER_URL | BWALL_GROUP=merger.$CIRCLE_BRANCH BWALL_NAME=$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME bash'}},
      ],
    }, deploy_nightly => {
      machine => $machine,
      steps => [
        'checkout',
        {deploy => {command => "git fetch --unshallow origin master || git fetch origin master\x0Agit checkout master || git checkout -b master origin/master\x0A".'git merge -m "auto-merge $CIRCLE_BRANCH ($CIRCLE_SHA1) into master" $CIRCLE_SHA1'."\x0Agit push origin master\x0A" .
                        'curl -sSf $BWALLER_URL | BWALL_GROUP=merger.$CIRCLE_BRANCH BWALL_NAME=$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME bash'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {'deploy_nightly' => {filters => {branches => {only => ['nightly']}},
                            requires => ['build'],
                            context => ['deploy-context']}},
      {'deploy_staging' => {filters => {branches => {only => ['staging']}},
                            requires => ['build'],
                            context => ['deploy-context']}},
    ]}},
  }}}],
  [{circleci => {merger => {into => 'dev'}}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }, deploy_staging => {
      machine => $machine,
      steps => [
        'checkout',
        {deploy => {command => "git fetch --unshallow origin dev || git fetch origin dev\x0Agit checkout dev || git checkout -b dev origin/dev\x0A".'git merge -m "auto-merge $CIRCLE_BRANCH ($CIRCLE_SHA1) into dev" $CIRCLE_SHA1'."\x0Agit push origin dev\x0A" .
                        'curl -sSf $BWALLER_URL | BWALL_GROUP=merger.$CIRCLE_BRANCH BWALL_NAME=$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME bash'}},
      ],
    }, deploy_nightly => {
      machine => $machine,
      steps => [
        'checkout',
        {deploy => {command => "git fetch --unshallow origin dev || git fetch origin dev\x0Agit checkout dev || git checkout -b dev origin/dev\x0A".'git merge -m "auto-merge $CIRCLE_BRANCH ($CIRCLE_SHA1) into dev" $CIRCLE_SHA1'."\x0Agit push origin dev\x0A" .
                        'curl -sSf $BWALLER_URL | BWALL_GROUP=merger.$CIRCLE_BRANCH BWALL_NAME=$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME bash'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {'deploy_nightly' => {filters => {branches => {only => ['nightly']}},
                            requires => ['build'],
                            context => ['deploy-context']}},
      {'deploy_staging' => {filters => {branches => {only => ['staging']}},
                            requires => ['build'],
                            context => ['deploy-context']}},
    ]}},
  }}}],
  [{circleci => {awscli => 1}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command =>
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version"
               }},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {deploy_branch => {
    x => [{awscli => 1}],
  }}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => "if [ \"\${CIRCLE_BRANCH}\" == 'x' ]; then\ntrue\n" .
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version"
                 . "\nfi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {parallel => \1}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      parallelism => 2,
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {
    parallel => 1,
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      parallelism => 2,
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {parallel => 4}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      parallelism => 4,
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}, 'parallel 4'],
  [{circleci => {
    build_generated_files => [],
    parallel => 4,
    tests => ['test1'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, test => {
      parallelism => 4,
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test1'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {test => {requires => ['build']}},
    ]}},
  }}}, 'parallel 4 build and test'],
  [{circleci => {parallel => 0}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {parallel => \0}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {build => [
    {command => 'a'},
    {command => 'b', branch => 'c'},
  ]}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'a'}},
        {run => {command => q{if [ "${CIRCLE_BRANCH}" == 'c' ]; then} . "\x0Atrue\x0A" . 'b' . "\x0Afi"}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {build => [
    {command => 'a', parallel => 1},
    {command => 'b', parallel => 0},
  ]}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'a'}},
        {run => {command => q{if [ "${CIRCLE_NODE_INDEX}" == "0" ]; then} . "\x0A" . "true\x0A" . 'b' . "\x0Afi"}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {build => [
    {command => ['a', 'b']},
  ]}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'a' . "\n" . 'b'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {build => [
    {command => ['a', 'b']},
  ], deploy_branch => {
    b1 => ['c'],
    b2 => ['d'],
  }}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'a' . "\n" . 'b'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'b1' ]; then} . "\x0Atrue\x0A" . 'c' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'b2' ]; then} . "\x0Atrue\x0A" . 'd' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}, 'deploy branch'],
  [{circleci => {build => [
    {command => ['a', 'b']},
  ], deploy_branch => {
    b1 => ['c'],
    b2 => ['d'],
  }, build_generated_files => []}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'a' . "\n" . 'b'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, deploy_b1 => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'c'}},
      ],
    }, deploy_b2 => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'd'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{}},
      {deploy_b1 => {requires => ['build'],
                     filters => {branches => {only => ['b1']}},
                     context => ['deploy-context']}},
      {deploy_b2 => {requires => ['build'],
                     filters => {branches => {only => ['b2']}},
                     context => ['deploy-context']}},
    ]}},
  }}}, 'deploy branch jobs'],
  [{circleci => {
    empty => 1,
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {},
    workflows => {version => 2},
  }}}],
  [{circleci => {
    gaa => 1,
    empty => 1,
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {
      gaa4 => {
        machine => $machine,
        steps => [
          "checkout",
          {run => {command => 'git config --global user.email "temp@circleci.test";git config --global user.name "CircleCI"'}},
          {run => {command => 'make deps'}},
          {run => {command => 'make updatenightly'}},
          {deploy => {command => 'git diff-index --quiet HEAD --cached || git commit -m auto'}},
          {deploy => {command => 'git push origin +`git rev-parse HEAD`:refs/heads/nightly'}},
        ],
      },
    },
    workflows => {version => 2, gaa4 => {
      jobs => ['gaa4'],
      "triggers" => [
        {
          "schedule" => {
            "cron" => "56 8 * * *",
            "filters" => {
              "branches" => {
                "only" => [
                  "master"
                ]
              }
            }
          }
        }
      ],
    }},
  }}}],
  [{circleci => {gaa => 1}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {
      gaa4 => {
        machine => $machine,
        steps => [
          "checkout",
          {run => {command => 'git config --global user.email "temp@circleci.test";git config --global user.name "CircleCI"'}},
          {run => {command => 'make deps'}},
          {run => {command => 'make updatenightly'}},
          {deploy => {command => 'git diff-index --quiet HEAD --cached || git commit -m auto'}},
          {deploy => {command => 'git push origin +`git rev-parse HEAD`:refs/heads/nightly'}},
        ],
      },
      build => {
        machine => $machine,
        environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
        steps => [
          'checkout',
          {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
          {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        ],
      },
    },
    workflows => {version => 2, gaa4 => {
      jobs => ['gaa4'],
      "triggers" => [
        {
          "schedule" => {
            "cron" => "37 8 * * *",
            "filters" => {
              "branches" => {
                "only" => [
                  "master"
                ]
              }
            }
          }
        }
      ],
    }, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {autobuild => 1}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {
      build => {
        machine => $machine,
        environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
        steps => [
          'checkout',
          {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
          {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        ],
      },
    },
    workflows => {version => 2, autobuild => {
      jobs => [
        "build",
        {"test" => {requires => ['build']}},
        {"deploy_master" => {requires => ['build', 'test'],
                              context => ['deploy-context']}},
      ],
      "triggers" => [
        {
          "schedule" => {
            "cron" => "55 19 * * *",
            "filters" => {
              "branches" => {
                "only" => [
                  "master"
                ]
              }
            }
          }
        }
      ],
    }, build => {jobs => [{'build'=>{}}]}},
  }}}, 'circleci autobuild'],
  [{circleci => {
    build_generated_files => [],
    parallel => 4,
    tests => ['test1'],
    tested_branches => ['b2', 'b1'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, test => {
      parallelism => 4,
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test1'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{filters => {branches => {only => ['b1', 'b2']}}}},
      {test => {requires => ['build'],
                filters => {branches => {only => ['b1', 'b2']}}}},
    ]}},
  }}}, 'parallel 4 build and test + tested_branches'],
  [{circleci => {
    make_deploy_branches => ['master', 'staging'],
    tested_branches => ['test1'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} . "\x0Atrue\x0A" . 'make deploy-master' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'staging' ]; then} . "\x0Atrue\x0A" . 'make deploy-staging' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{
      filters => {branches => {only => ['master', 'staging', 'test1']}},
    }}]}},
  }}}, 'tested_branches + make_deploy_branches'],
  [{circleci => {build => [
    {command => ['a', 'b']},
  ], tested_branches => ['x', 'y'], deploy_branch => {
    b1 => ['c'],
    b2 => ['d'],
  }, build_generated_files => []}} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'a' . "\n" . 'b'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, deploy_b1 => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'c'}},
      ],
    }, deploy_b2 => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'd'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{filters => {branches => {only => [qw(b1 b2 x y)]}}}},
      {deploy_b1 => {requires => ['build'],
                     filters => {branches => {only => ['b1']}},
                     context => ['deploy-context']}},
      {deploy_b2 => {requires => ['build'],
                     filters => {branches => {only => ['b2']}},
                     context => ['deploy-context']}},
    ]}},
  }}}, 'deploy branch jobs + tested_branches'],
  [{circleci => {
    build_generated_files => ['foo', 'bar'],
    tests => {
      t1 => ['test3'],
      t2 => ['test4'],
    },
    make_deploy_branches => ['master', {name => 'devel', testless => 1}],
    tested_branches => ['xyz'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp', 'foo', 'bar'],
        }},
      ],
    }, 'test-t1' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t1'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test3'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t1'}},
      ],
    }, 'test-t2' => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test-t2'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test4'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test-t2'}},
      ],
    }, deploy_master => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'make deploy-master'}},
      ],
    }, early_deploy_devel => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => 'make deploy-devel'}},
      ],
    }, before_tests => {
      machine => $machine,
      steps => [{run => {command => 'true'}}],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=>{filters => {branches => {only => ['master', 'xyz']}}}},
      {early_deploy_devel => {requires => ['build'],
                              filters => {branches => {only => ['devel']}},
                              context => ['deploy-context']}},
      {before_tests => {requires => ['build'],
                        filters => {branches => {only => ['master', 'xyz']}}}},
      {'test-t1' => {requires => ['build', 'before_tests'],
                     filters => {branches => {only => ['master', 'xyz']}}}},
      {'test-t2' => {requires => ['build', 'before_tests'],
                     filters => {branches => {only => ['master', 'xyz']}}}},
      {deploy_master => {requires => ['build', 'test-t1', 'test-t2'],
                         filters => {branches => {only => ['master']}},
                         context => ['deploy-context']}},
    ]}},
  }}}, 'Multiple test steps with test-less deploy + tested_branches'],
  [{circleci => {
    params => ['ab', 'x_y'],
    build_generated_files => [],
    tests => ['test1'],
  }} => {'.circleci/config.yml' => {json => {
    version => $circleci_version,
    parameters => {
      ab => {
        type => 'string',
        default => '',
      },
      'x_y' => {
        type => 'string',
        default => '',
      },
    },
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build',
                      AB => '<< pipeline.parameters.ab >>',
                      X_Y => '<< pipeline.parameters.x_y >>'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {"persist_to_workspace" => {
          "root" => "./",
          "paths" => ['.ciconfigtemp'],
        }},
      ],
    }, test => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test',
                      AB => '<< pipeline.parameters.ab >>',
                      X_Y => '<< pipeline.parameters.x_y >>'},
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'test1'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [
      {'build'=> {}},
      {test => {requires => ['build']}},
    ]}},
  }}}, 'params'],
  
  [{github => {}} => {'.github/workflows/test.yml' => {remove => 1}}, 'github empty'],
  [{github => {"#hoge" => 1}} => {'.github/workflows/test.yml' => {remove => 1}}, 'github empty'],
  [{github => {pmbp => 'latest'}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           experimental => \0}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}],
  [{github => {pmbp => 1}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           experimental => \0},
                                          {perl_version => '5.8.9',
                                           experimental => \0}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}],
  [{github => {pmbp => '5.8+'}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           experimental => \0},
                                          {perl_version => '5.8.9',
                                           experimental => \0}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}],
  [{github => {pmbp => '5.10+'}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           experimental => \0},
                                          {perl_version => '5.10.1',
                                           experimental => \0}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}],
  [{github => {pmbp => '5.14+'}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           experimental => \0}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}],
  [{github => {merger => 1}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {deploy_github_nightly => {
      if => q{${{ github.ref == 'refs/heads/nightly' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {
          "uses" => 'actions/checkout@v2',
          "with" => {
            "fetch-depth" => 0,
            "ref" => "master",
            "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
          }
        },
        {"run" => 'git config --global user.name "GitHub Actions"'},
        {"run" => 'git config --global user.email "temp@github.test"'},
        {run => 'git fetch --unshallow origin master || git fetch origin master'},
        {run => 'git checkout master || git checkout -b master origin/master'},
        {"run" => 'git merge -m "auto-merge $GITHUB_REF ($GITHUB_SHA) into master" $GITHUB_SHA'},
        {run => 'git push origin master'},
        {run => 'curl -sSf $BWALLER_URL | BWALL_GROUP=merger.${GITHUB_REF/refs\/heads\//} BWALL_NAME=${GITHUB_REPOSITORY} bash',
         env => {BWALLER_URL => q<${{ secrets.BWALLER_URL }}>}},
      ],
    }, deploy_github_staging => {
      if => q{${{ github.ref == 'refs/heads/staging' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {
          "uses" => 'actions/checkout@v2',
          "with" => {
            "fetch-depth" => 0,
            "ref" => "master",
            "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
          }
        },
        {"run" => 'git config --global user.name "GitHub Actions"'},
        {"run" => 'git config --global user.email "temp@github.test"'},
        {run => 'git fetch --unshallow origin master || git fetch origin master'},
        {run => 'git checkout master || git checkout -b master origin/master'},
        {"run" => 'git merge -m "auto-merge $GITHUB_REF ($GITHUB_SHA) into master" $GITHUB_SHA'},
        {run => 'git push origin master'},
        {run => 'curl -sSf $BWALLER_URL | BWALL_GROUP=merger.${GITHUB_REF/refs\/heads\//} BWALL_NAME=${GITHUB_REPOSITORY} bash',
         env => {BWALLER_URL => q<${{ secrets.BWALLER_URL }}>}},
      ],
    }},
  }}}, 'merger'],
  [{github => {merger => {needupdate => ['foo/bar']}}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {deploy_github_nightly => {
      if => q{${{ github.ref == 'refs/heads/nightly' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {
          "uses" => 'actions/checkout@v2',
          "with" => {
            "fetch-depth" => 0,
            "ref" => "master",
            "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
          }
        },
        {"run" => 'git config --global user.name "GitHub Actions"'},
        {"run" => 'git config --global user.email "temp@github.test"'},
        {run => 'git fetch --unshallow origin master || git fetch origin master'},
        {run => 'git checkout master || git checkout -b master origin/master'},
        {"run" => 'git merge -m "auto-merge $GITHUB_REF ($GITHUB_SHA) into master" $GITHUB_SHA'},
        {run => 'git push origin master'},
        {run => 'curl -f -s -S --request POST --header "Authorization:token $GH_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\"event_type\":\"needupdate\"}" "https://api.github.com/repos/foo/bar/dispatches"',
         env => {GH_ACCESS_TOKEN => q<${{ secrets.GH_ACCESS_TOKEN }}>}},
        {run => 'curl -sSf $BWALLER_URL | BWALL_GROUP=merger.${GITHUB_REF/refs\/heads\//} BWALL_NAME=${GITHUB_REPOSITORY} bash',
         env => {BWALLER_URL => q<${{ secrets.BWALLER_URL }}>}},
      ],
    }, deploy_github_staging => {
      if => q{${{ github.ref == 'refs/heads/staging' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {
          "uses" => 'actions/checkout@v2',
          "with" => {
            "fetch-depth" => 0,
            "ref" => "master",
            "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
          }
        },
        {"run" => 'git config --global user.name "GitHub Actions"'},
        {"run" => 'git config --global user.email "temp@github.test"'},
        {run => 'git fetch --unshallow origin master || git fetch origin master'},
        {run => 'git checkout master || git checkout -b master origin/master'},
        {"run" => 'git merge -m "auto-merge $GITHUB_REF ($GITHUB_SHA) into master" $GITHUB_SHA'},
        {run => 'git push origin master'},
        {run => 'curl -f -s -S --request POST --header "Authorization:token $GH_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\"event_type\":\"needupdate\"}" "https://api.github.com/repos/foo/bar/dispatches"',
         env => {GH_ACCESS_TOKEN => q<${{ secrets.GH_ACCESS_TOKEN }}>}},
        {run => 'curl -sSf $BWALLER_URL | BWALL_GROUP=merger.${GITHUB_REF/refs\/heads\//} BWALL_NAME=${GITHUB_REPOSITORY} bash',
         env => {BWALLER_URL => q<${{ secrets.BWALLER_URL }}>}},
      ],
    }},
  }}}, 'merger + needupdate'],
  [{github => {pmbp => 'latest',
               merger => 1}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           experimental => \0}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }, deploy_github_nightly => {
      if => q{${{ github.ref == 'refs/heads/nightly' }}},
      'runs-on' => 'ubuntu-latest',
      needs => ['test'],
      steps => [
        {
          "uses" => 'actions/checkout@v2',
          "with" => {
            "fetch-depth" => 0,
            "ref" => "master",
            "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
          }
        },
        {"run" => 'git config --global user.name "GitHub Actions"'},
        {"run" => 'git config --global user.email "temp@github.test"'},
        {run => 'git fetch --unshallow origin master || git fetch origin master'},
        {run => 'git checkout master || git checkout -b master origin/master'},
        {"run" => 'git merge -m "auto-merge $GITHUB_REF ($GITHUB_SHA) into master" $GITHUB_SHA'},
        {run => 'git push origin master'},
        {run => 'curl -sSf $BWALLER_URL | BWALL_GROUP=merger.${GITHUB_REF/refs\/heads\//} BWALL_NAME=${GITHUB_REPOSITORY} bash',
         env => {BWALLER_URL => q<${{ secrets.BWALLER_URL }}>}},
      ],
    }, deploy_github_staging => {
      if => q{${{ github.ref == 'refs/heads/staging' }}},
      'runs-on' => 'ubuntu-latest',
      needs => ['test'],
      steps => [
        {
          "uses" => 'actions/checkout@v2',
          "with" => {
            "fetch-depth" => 0,
            "ref" => "master",
            "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
          }
        },
        {"run" => 'git config --global user.name "GitHub Actions"'},
        {"run" => 'git config --global user.email "temp@github.test"'},
        {run => 'git fetch --unshallow origin master || git fetch origin master'},
        {run => 'git checkout master || git checkout -b master origin/master'},
        {"run" => 'git merge -m "auto-merge $GITHUB_REF ($GITHUB_SHA) into master" $GITHUB_SHA'},
        {run => 'git push origin master'},
        {run => 'curl -sSf $BWALLER_URL | BWALL_GROUP=merger.${GITHUB_REF/refs\/heads\//} BWALL_NAME=${GITHUB_REPOSITORY} bash',
         env => {BWALLER_URL => q<${{ secrets.BWALLER_URL }}>}},
      ],
    }},
  }}}],
  [{github => {needupdate => ['test1/test2']}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {deploy_github_master => {
      if => q{${{ github.ref == 'refs/heads/master' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {run => 'curl -f -s -S --request POST --header "Authorization:token $GH_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\"event_type\":\"needupdate\"}" "https://api.github.com/repos/test1/test2/dispatches"',
         env => {GH_ACCESS_TOKEN => q<${{ secrets.GH_ACCESS_TOKEN }}>}},
      ],
    }},
  }}}, 'needupdate'],
  [{config => {
    default_branch => 'hoge',
  }, github => {needupdate => ['test1/test2']}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {deploy_github_hoge => {
      if => q{${{ github.ref == 'refs/heads/hoge' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {run => 'curl -f -s -S --request POST --header "Authorization:token $GH_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\"event_type\":\"needupdate\"}" "https://api.github.com/repos/test1/test2/dispatches"',
         env => {GH_ACCESS_TOKEN => q<${{ secrets.GH_ACCESS_TOKEN }}>}},
      ],
    }},
  }}}, 'needupdate default branch'],
  [{github => {
    needupdate => ['master'], autobuild => 1,
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}, schedule => [{cron => "36 17 * * *"}]},
    jobs => {deploy_github_master => {
      if => q{${{ github.ref == 'refs/heads/master' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {run => 'curl -f -s -S --request POST --header "Authorization:token $GH_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\"event_type\":\"needupdate\"}" "https://api.github.com/repos/master/dispatches"',
         env => {GH_ACCESS_TOKEN => q<${{ secrets.GH_ACCESS_TOKEN }}>}},
      ],
    }},
  }}, '.github/.touch' => {touch => 1}}, 'needupdate autobuild'],
  [{github => {gaa => 1}} => {'.github/workflows/cron.yml' => {json => {
    name => 'cron',
    on => {schedule => [{cron => '23 19 * * *'}]},
    jobs => {batch_github_master => {
      if => q{${{ github.ref == 'refs/heads/master' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {
          "uses" => 'actions/checkout@v2',
          "with" => {
            "fetch-depth" => 0,
            "ref" => "master",
            "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
          }
        },
        {"run" => 'git config --global user.name "GitHub Actions"'},
        {"run" => 'git config --global user.email "temp@github.test"'},
        {run => 'make deps'},
        {run => 'make updatenightly'},
        {run => 'git diff-index --quiet HEAD --cached || git commit -m auto'},
        {run => 'git push origin +`git rev-parse HEAD`:refs/heads/nightly'},
      ],
    }},
  }}, '.github/.touch' => {touch => 1}}, 'gaa'],
  [{config => {
    default_branch => 'fuga',
  }, github => {gaa => 1}} => {'.github/workflows/cron.yml' => {json => {
    name => 'cron',
    on => {schedule => [{cron => '24 16 * * *'}]},
    jobs => {batch_github_fuga => {
      if => q{${{ github.ref == 'refs/heads/fuga' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {
          "uses" => 'actions/checkout@v2',
          "with" => {
            "fetch-depth" => 0,
            "ref" => "master",
            "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
          }
        },
        {"run" => 'git config --global user.name "GitHub Actions"'},
        {"run" => 'git config --global user.email "temp@github.test"'},
        {run => 'make deps'},
        {run => 'make updatenightly'},
        {run => 'git diff-index --quiet HEAD --cached || git commit -m auto'},
        {run => 'git push origin +`git rev-parse HEAD`:refs/heads/nightly'},
      ],
    }},
  }}, '.github/.touch' => {touch => 1}}, 'gaa with default_branch'],
  [{github => {gaa => {
    build => ['foo', 'a b ${{ a.b }}'],
  }}} => {'.github/workflows/cron.yml' => {json => {
    name => 'cron',
    on => {schedule => [{cron => '51 20 * * *'}]},
    jobs => {batch_github_master => {
      if => q{${{ github.ref == 'refs/heads/master' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {
          "uses" => 'actions/checkout@v2',
          "with" => {
            "fetch-depth" => 0,
            "ref" => "master",
            "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
          }
        },
        {"run" => 'git config --global user.name "GitHub Actions"'},
        {"run" => 'git config --global user.email "temp@github.test"'},
        {run => 'foo'},
        {run => 'a b ${{ a.b }}'},
        {run => 'make updatenightly'},
        {run => 'git diff-index --quiet HEAD --cached || git commit -m auto'},
        {run => 'git push origin +`git rev-parse HEAD`:refs/heads/nightly'},
      ],
    }},
  }}, '.github/.touch' => {touch => 1}}, 'gaa with build steps'],
  [{github => {
    build => ['b'], tests => ['a'], autobuild => 1,
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}, schedule => [{cron => "6 18 * * *"}]},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'b'},
        {run => 'a'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}, '.github/.touch' => {touch => 1}}, 'github autobuild'],
  [{github => {updatebyhook => 1}} => {'.github/workflows/hook.yml' => {json => {
    name => 'hook',
    on => {repository_dispatch => {types => ['needupdate']}},
    jobs => {hook_needupdate => {
      if => q{${{ github.ref == 'refs/heads/master' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {
          "uses" => 'actions/checkout@v2',
          "with" => {
            "fetch-depth" => 0,
            "ref" => "master",
            "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
          }
        },
        {"run" => 'git config --global user.name "GitHub Actions"'},
        {"run" => 'git config --global user.email "temp@github.test"'},
        {run => 'make updatebyhook'},
        {run => 'git diff-index --quiet HEAD --cached || git commit -m updatebyhook'},
        {run => 'git push origin +`git rev-parse HEAD`:refs/heads/nightly'},
      ],
    }},
  }}}, 'updatebyhook'],
  [{github => {
    build => [{run => 'a', branch => "a/b"}],
    tests => ["b"],
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'a', if => q{${{ github.ref == 'refs/heads/a/b' }}}},
        {run => 'b'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'build with branch'],
  [{github => {
    build => ['b'], tests => ['a'],
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'b'},
        {run => 'a'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'tests'],
  [{github => {
    build => ["b"],
    tests => [{run => 'a', branch => "a/b"}],
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'b'},
        {run => 'a',
         if => q{${{ github.ref == 'refs/heads/a/b' }}}},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => q{${{ always () }}}},
      ],
    }},
  }}}, 'tests with branch'],
  [{github => {tests => ['a']}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'a'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'tests'],
  [{github => {macos => 1,
               tests => ['a']}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => '${{ matrix.os }}',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{os => 'ubuntu-latest',
                                           experimental => \0},
                                          {os => 'macos-latest',
                                           experimental => \0}]},
                   'fail-fast' => \0},
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'a'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'macos'],
  [{github => {macos => 1,
               tests => {
                 x => ['a'],
                 y => ['b'],
               }}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => '${{ matrix.os }}',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{os => 'ubuntu-latest',
                                           experimental => \0},
                                          {os => 'macos-latest',
                                           experimental => \0}]},
                   'fail-fast' => \0},
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'a'},
        {run => 'b'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'macos multiple tests'],
  [{github => {pmbp => 'latest', macos => 1}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => '${{ matrix.os }}',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           experimental => \0}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'macos + pmbp'],
  [{github => {pmbp => 'latest', macos => {latest_perl_only => 1}}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => '${{ matrix.os }}',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           experimental => \0}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'macos latest perl'],
  [{github => {pmbp => '5.14+', macos => {latest_perl_only => 1}}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => '${{ matrix.os }}',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'ubuntu-latest',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'macos-latest',
                                           experimental => \1}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'macos latest perl + 5.14+'],
  [{github => {
    pmbp => '5.14+', macos => {latest_perl_only => 1},
    env_matrix => {
      FOO => ['a', 'bar'],
      BAR => ['x', 'y'],
    },
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => '${{ matrix.os }}',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'y',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'y',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'y',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'y',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'y',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'y',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'macos-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'x',
                                           experimental => \1},
                                          {perl_version => '5.14.2',
                                           os => 'macos-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'x',
                                           experimental => \1},
                                          {perl_version => '5.14.2',
                                           os => 'macos-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'y',
                                           experimental => \1},
                                          {perl_version => '5.14.2',
                                           os => 'macos-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'y',
                                           experimental => \1}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              'FOO' => '${{ matrix.env_FOO }}',
              'BAR' => '${{ matrix.env_BAR }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'macos latest perl + 5.14+ + custom matrix'],
  [{github => {
    pmbp => '5.14+', macos => {latest_perl_only => 1},
    env_matrix => {
      FOO => ['a', 'bar'],
      BAR => ['x', 'y'],
    },
    matrix_allow_failure => [{env_FOO => 'a', env_BAR => 'x',
                         os => 'macos-latest'},
                        {perl_version => 'latest',
                         os => 'ubuntu-latest',
                         env_BAR => 'y'}],
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => '${{ matrix.os }}',
      'continue-on-error' => '${{ matrix.experimental }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'y',
                                           experimental => \1},
                                          {perl_version => 'latest',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'y',
                                           experimental => \1},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'x',
                                           experimental => \1},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'y',
                                           experimental => \0},
                                          {perl_version => 'latest',
                                           os => 'macos-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'y',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'x',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'y',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'ubuntu-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'y',
                                           experimental => \0},
                                          {perl_version => '5.14.2',
                                           os => 'macos-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'x',
                                           experimental => \1},
                                          {perl_version => '5.14.2',
                                           os => 'macos-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'x',
                                           experimental => \1},
                                          {perl_version => '5.14.2',
                                           os => 'macos-latest',
                                           env_FOO => 'a',
                                           env_BAR => 'y',
                                           experimental => \1},
                                          {perl_version => '5.14.2',
                                           os => 'macos-latest',
                                           env_FOO => 'bar',
                                           env_BAR => 'y',
                                           experimental => \1}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              'FOO' => '${{ matrix.env_FOO }}',
              'BAR' => '${{ matrix.env_BAR }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'custom matrix allow failure'],
  [{github => {pages => 1}} => {'.github/workflows/pages.yml' => {json => {
    name => 'pages',
    on => {
      push => {
        branches => ['master'],
      },
    },
    permissions => {
      contents => 'read',
      pages => 'write',
      'id-token' => 'write',
    },
    concurrency => {
      group => 'pages',
      'cancel-in-progress' => \1,
    },
    jobs => {
      deploy => {
        environment => {
          name => 'github-pages',
          url => '${{ steps.deployment.outputs.page_url }}',
        },
        'runs-on' => 'ubuntu-latest',
        steps => [
          {name => 'Checkout', uses => 'actions/checkout@v2',
           "with" => {
             "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
           }},
          {run => 'make build-github-pages'},
          {name => 'Setup pages', uses => 'actions/configure-pages@v3'},
          {name => 'Upload artifact',
           uses => 'actions/upload-pages-artifact@v2',
           with => {path => '.'}},
          {name => 'Deploy', id => 'deployment',
           uses => 'actions/deploy-pages@v3'},
        ],
      },
    },
  }}}, 'github pages'],
  [{github => {pages => {
    branch => 'abc/def',
  }}} => {'.github/workflows/pages.yml' => {json => {
    name => 'pages',
    on => {
      push => {
        branches => ['abc/def'],
      },
    },
    permissions => {
      contents => 'read',
      pages => 'write',
      'id-token' => 'write',
    },
    concurrency => {
      group => 'pages',
      'cancel-in-progress' => \1,
    },
    jobs => {
      deploy => {
        environment => {
          name => 'github-pages',
          url => '${{ steps.deployment.outputs.page_url }}',
        },
        'runs-on' => 'ubuntu-latest',
        steps => [
          {name => 'Checkout', uses => 'actions/checkout@v2',
           "with" => {
             "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
           }},
          {run => 'make build-github-pages'},
          {name => 'Setup pages', uses => 'actions/configure-pages@v3'},
          {name => 'Upload artifact',
           uses => 'actions/upload-pages-artifact@v2',
           with => {path => '.'}},
          {name => 'Deploy', id => 'deployment',
           uses => 'actions/deploy-pages@v3'},
        ],
      },
    },
  }}}, 'github pages with branch'],
  [{github => {pages => {
    build_secrets => ['ab', 'c'],
  }}} => {'.github/workflows/pages.yml' => {json => {
    name => 'pages',
    on => {
      push => {
        branches => ['master'],
      },
    },
    permissions => {
      contents => 'read',
      pages => 'write',
      'id-token' => 'write',
    },
    concurrency => {
      group => 'pages',
      'cancel-in-progress' => \1,
    },
    jobs => {
      deploy => {
        environment => {
          name => 'github-pages',
          url => '${{ steps.deployment.outputs.page_url }}',
        },
        'runs-on' => 'ubuntu-latest',
        steps => [
          {name => 'Checkout', uses => 'actions/checkout@v2',
           "with" => {
             "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
           }},
          {run => 'make build-github-pages',
           env => {ab => '${{ secrets.ab }}',
                   c => '${{ secrets.c }}'}},
          {name => 'Setup pages', uses => 'actions/configure-pages@v3'},
          {name => 'Upload artifact',
           uses => 'actions/upload-pages-artifact@v2',
           with => {path => '.'}},
          {name => 'Deploy', id => 'deployment',
           uses => 'actions/deploy-pages@v3'},
        ],
      },
    },
  }}}, 'github pages with build secrets'],
  [{github => {pages => 1,
               tests => ['a']}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'a'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}, '.github/workflows/pages.yml' => {json => {
    name => 'pages',
    on => {
      workflow_run => {
        branches => ['master'],
        types => ['completed'],
        workflows => ['test'],
      },
    },
    permissions => {
      contents => 'read',
      pages => 'write',
      'id-token' => 'write',
    },
    concurrency => {
      group => 'pages',
      'cancel-in-progress' => \1,
    },
    jobs => {
      deploy => {
        environment => {
          name => 'github-pages',
          url => '${{ steps.deployment.outputs.page_url }}',
        },
        'runs-on' => 'ubuntu-latest',
        if => q{${{ github.event.workflow_run.conclusion == 'success' }}},
        steps => [
          {name => 'Checkout', uses => 'actions/checkout@v2',
           "with" => {
             "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
           }},
          {run => 'make build-github-pages'},
          {name => 'Setup pages', uses => 'actions/configure-pages@v3'},
          {name => 'Upload artifact',
           uses => 'actions/upload-pages-artifact@v2',
           with => {path => '.'}},
          {name => 'Deploy', id => 'deployment',
           uses => 'actions/deploy-pages@v3'},
        ],
      },
    },
  }}}, 'github pages and tests'],
  [{github => {pages => {
    branch => 'abc/def',
  }, tests => ['a'],
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'a'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}, '.github/workflows/pages.yml' => {json => {
    name => 'pages',
    on => {
      workflow_run => {
        branches => ['abc/def'],
        types => ['completed'],
        workflows => ['test'],
      },
    },
    permissions => {
      contents => 'read',
      pages => 'write',
      'id-token' => 'write',
    },
    concurrency => {
      group => 'pages',
      'cancel-in-progress' => \1,
    },
    jobs => {
      deploy => {
        environment => {
          name => 'github-pages',
          url => '${{ steps.deployment.outputs.page_url }}',
        },
        'runs-on' => 'ubuntu-latest',
        if => q{${{ github.event.workflow_run.conclusion == 'success' }}},
        steps => [
          {name => 'Checkout', uses => 'actions/checkout@v2',
           "with" => {
             "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
           }},
          {run => 'make build-github-pages'},
          {name => 'Setup pages', uses => 'actions/configure-pages@v3'},
          {name => 'Upload artifact',
           uses => 'actions/upload-pages-artifact@v2',
           with => {path => '.'}},
          {name => 'Deploy', id => 'deployment',
           uses => 'actions/deploy-pages@v3'},
        ],
      },
    },
  }}}, 'github pages with branch and tests'],
  [{github => {pages => {
    after => 1,
  }}} => {'.github/workflows/pages.yml' => {json => {
    name => 'pages',
    on => {
      push => {
        branches => ['master'],
      },
    },
    permissions => {
      contents => 'read',
      pages => 'write',
      'id-token' => 'write',
    },
    concurrency => {
      group => 'pages',
      'cancel-in-progress' => \1,
    },
    jobs => {
      deploy => {
        environment => {
          name => 'github-pages',
          url => '${{ steps.deployment.outputs.page_url }}',
        },
        'runs-on' => 'ubuntu-latest',
        steps => [
          {name => 'Checkout', uses => 'actions/checkout@v2',
           "with" => {
             "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
           }},
          {run => 'make build-github-pages'},
          {name => 'Setup pages', uses => 'actions/configure-pages@v3'},
          {name => 'Upload artifact',
           uses => 'actions/upload-pages-artifact@v2',
           with => {path => '.'}},
          {name => 'Deploy', id => 'deployment',
           uses => 'actions/deploy-pages@v3'},
          {run => 'make deployed-github-pages'},
        ],
      },
    },
  }}}, 'github pages with after'],
  [{github => {pages => {
    after => 1,
    after_secrets => ['ab', 'X'],
  }}} => {'.github/workflows/pages.yml' => {json => {
    name => 'pages',
    on => {
      push => {
        branches => ['master'],
      },
    },
    permissions => {
      contents => 'read',
      pages => 'write',
      'id-token' => 'write',
    },
    concurrency => {
      group => 'pages',
      'cancel-in-progress' => \1,
    },
    jobs => {
      deploy => {
        environment => {
          name => 'github-pages',
          url => '${{ steps.deployment.outputs.page_url }}',
        },
        'runs-on' => 'ubuntu-latest',
        steps => [
          {name => 'Checkout', uses => 'actions/checkout@v2',
           "with" => {
             "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
           }},
          {run => 'make build-github-pages'},
          {name => 'Setup pages', uses => 'actions/configure-pages@v3'},
          {name => 'Upload artifact',
           uses => 'actions/upload-pages-artifact@v2',
           with => {path => '.'}},
          {name => 'Deploy', id => 'deployment',
           uses => 'actions/deploy-pages@v3'},
          {run => 'make deployed-github-pages',
           env => {ab => '${{ secrets.ab }}',
                   X => '${{ secrets.X }}'}},
        ],
      },
    },
  }}}, 'github pages with after_secrets'],
  [{github => {
    build => [{docker_build => 'foo.test/bar/z123'}],
    tests => ['x'],
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'docker build -t foo\\.test\\/bar\\/z123 \\.'},
        {run => 'x'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'github docker_build'],
  [{github => {
    build => [{docker_build => 'foo.test/bar/z123',
               path => "foo/bar"}],
    tests => ['x'],
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'docker build -t foo\\.test\\/bar\\/z123 foo\\/bar'},
        {run => 'x'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'github docker_build with path'],
  [{github => {
    tests => ['x', {docker_push => 'foo.test/bar/z123'}],
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'x'},
        {run => 'docker login -u $DOCKER_USER -p $DOCKER_PASS foo\\.test',
         if => q{${{ github.ref == 'refs/heads/master' }}},
         env => {
           DOCKER_USER => q<${{ secrets.DOCKER_USER }}>,
           DOCKER_PASS => q<${{ secrets.DOCKER_PASS }}>,
         }},
        {run => 'docker push foo\\.test\\/bar\\/z123',
         if => q{${{ github.ref == 'refs/heads/master' }}}},
        {run => 'curl -sSf $BWALLER_URL | BWALL_GROUP=docker BWALL_NAME=foo.test/bar/z123 bash',
         if => q{${{ github.ref == 'refs/heads/master' }}},
         env => {
           BWALLER_URL => q<${{ secrets.BWALLER_URL }}>,
         }},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'github docker_push'],
  [{github => {
    tests => ['x', {docker_push => 'foo.test/bar/z123', branch => 'abc-def'}],
  }} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      env => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2',
         "with" => {
           "ssh-key" => '${{ secrets.GH_GIT_KEY }}',
         }},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'x'},
        {run => 'docker login -u $DOCKER_USER -p $DOCKER_PASS foo\\.test',
         if => q{${{ github.ref == 'refs/heads/abc-def' }}},
         env => {
           DOCKER_USER => q<${{ secrets.DOCKER_USER }}>,
           DOCKER_PASS => q<${{ secrets.DOCKER_PASS }}>,
         }},
        {run => 'docker push foo\\.test\\/bar\\/z123',
         if => q{${{ github.ref == 'refs/heads/abc-def' }}}},
        {run => 'curl -sSf $BWALLER_URL | BWALL_GROUP=docker BWALL_NAME=foo.test/bar/z123 bash',
         if => q{${{ github.ref == 'refs/heads/abc-def' }}},
         env => {
           BWALLER_URL => q<${{ secrets.BWALLER_URL }}>,
         }},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'},
         if => '${{ always () }}'},
      ],
    }},
  }}}, 'github docker_push with branch'],
  
  [{droneci => {}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [],
      when => {branch => []},
    }],
  }}}, 'droneci empty'],
  [{droneci => {"pmbp" => 1}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "make test-deps",
      ],
    }, {
      name => 'test-pmbp',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "make test"
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }],
  }}}, 'droneci pmbp'],
  [{droneci => {build => [
    "foo bar",
    "baz"
  ]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {branch => []},
    }],
  }}}, 'droneci build'],
  [{droneci => {tests => [
    "foo bar",
    "baz"
  ]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }],
  }}}, 'droneci tests'],
  [{droneci => {build => [
    "aaa"
  ], tests => [
    "foo bar",
    "baz"
  ]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }],
  }}}, 'droneci build tests'],
  [{droneci => {build => [
    "aaa"
  ], tests => {"a" => [
    "foo bar",
    "baz"
  ], "b" => ["x"]}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'test--b',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }],
  }}}, 'droneci build tests 2'],
  [{droneci => {build => [
    "aaa"
  ], tests => {"a" => {"commands" => [
    "foo bar",
    "baz"
  ], "branch" => "ab"}, "b" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    "branch" => "c",
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      when => {branch => ['ab', 'c', 'xb', 'yb']},
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
      when => {branch => ['ab']},
    }, {
      name => 'test--b',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
      when => {branch => ['c', 'xb', 'yb']},
    }],
  }}}, 'droneci build tests 3'],
  [{droneci => {build => [
    "aaa"
  ], tests => {"a" => {"commands" => [
    "foo bar",
    "baz"
  ], "branch" => "ab"}, "b" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    optional => 1,
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      when => {branch => ['ab', 'xb', 'yb']},
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
      when => {branch => ['ab']},
    }, {
      name => 'test--b',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
      when => {branch => ['xb', 'yb']},
    }],
  }}}, 'droneci optional test'],
  [{droneci => {build => [
    "aaa"
  ], tests => {"a" => {"commands" => [
    "foo bar",
    "baz"
  ], "branch" => "ab"}, "b" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    optional => 1,
  }}, deploy => ["c"]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      when => {branch => ['ab', 'master', 'xb', 'yb']},
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
      when => {branch => ['ab']},
    }, {
      name => 'deploy--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "c",
      ],
      depends_on => [qw(build test--a)],
      when => {branch => ['master'], event => ['push']},
    }, {
      name => 'test--b',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
      when => {branch => ['xb', 'yb']},
    }],
  }}}, 'droneci optional test and deploy'],
  [{droneci => {build => [
    "aaa"
  ], tests => {"a" => {"commands" => [
    "foo bar",
    "baz"
  ], "branch" => "ab"}, "b" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    optional => 1,
  }}, failed => ["c"]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      when => {branch => ['ab', 'xb', 'yb']},
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
      when => {branch => ['ab']},
    }, {
      name => 'test--b',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
      when => {branch => ['xb', 'yb']},
    }, {
      name => 'failed--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "c",
      ],
      depends_on => [qw(build test--a test--b)],
      when => {branch => ['ab', 'xb', 'yb'], status => ['failure']},
      failure => 'ignore',
    }],
  }}}, 'droneci optional test and failed'],
  [{droneci => {build => [
  ], tests => {"a" => {"commands" => [
    "foo bar",
  ], "group" => "ab"}, "b" => {
    "commands" => ["x"],
    group => 'ab',
  }, "c" => {commands => ["d"]}, "d" => {
    commands => ["e"],
    group => 'f',
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'test--b',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build test--a)],
    }, {
      name => 'test--c',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "d",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'test--d',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "e",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }],
  }}}, 'droneci build test groups'],
  [{droneci => {docker => 1}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }],
      commands => [
        "bash -c cd\\ \\\\\\/app\\ \\&\\&\\ perl\\ local\\/bin\\/pmbp\\.pl\\ \\-\\-install\\-commands\\ docker",
      ],
      when => {branch => []},
    }],
    volumes => [{
      name => 'dockersock',
      host => {path => '/var/run/docker.sock'},
    }],
  }}}, 'droneci docker'],
  [{droneci => {docker => {nested => 1}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        "mkdir -p /drone/src/local/ciconfig",
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'mkdir -p `cat /drone/src/local/ciconfig/dockershareddir`',
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        q{perl -e 'print "ciconfig-" . rand' > /drone/src/local/ciconfig/dockername},
        q{docker run --name `cat /drone/src/local/ciconfig/dockername` -v `cat /drone/src/local/ciconfig/dockershareddir`:`cat /drone/src/local/ciconfig/dockershareddir` -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp -d -t quay.io/wakaba/droneci-step-base bash},
      ],
      when => {branch => []},
    }, {
      name => 'cleanup-nested',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'docker stop `cat /drone/src/local/ciconfig/dockername`',
        'rm -fr `cat /drone/src/local/ciconfig/dockershareddir`',
      ],
      when => {
        status => ['failure', 'success'],
        branch => [],
      },
      failure => 'ignore',
      depends_on => [qw(build)],
    }],
    volumes => [{
      name => 'dockersock',
      host => {path => '/var/run/docker.sock'},
    }, {
      name => 'dockershareddir',
      host => {path => '/var/lib/docker/shareddir'},
    }],
  }}}, 'droneci docker nested'],
  [{droneci => {docker => 1, tests => [
    "ls",
    {command => "pwd", wd => "/foo"},
    {command => "ab", wd => "/bar"},
    "cd",
  ]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }],
      commands => [
        "bash -c cd\\ \\\\\\/app\\ \\&\\&\\ perl\\ local\\/bin\\/pmbp\\.pl\\ \\-\\-install\\-commands\\ docker",
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }],
      commands => [
        "bash -c cd\\ \\\\\\/app\\ \\&\\&\\ perl\\ local\\/bin\\/pmbp\\.pl\\ \\-\\-install\\-commands\\ docker",
        "ls",
        "bash -c cd\\ \\\\\\/foo\\ \\&\\&\\ pwd",
        "bash -c cd\\ \\\\\\/bar\\ \\&\\&\\ ab",
        "cd",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }],
    volumes => [{
      name => 'dockersock',
      host => {path => '/var/run/docker.sock'},
    }],
  }}}, 'droneci test wds'],
  [{droneci => {
    docker => {nested => 1},
    tests => [
      'a\\b',
      {"command" => 'a\\b'},
      {"command" => 'a\\b',
       wd => 'c\\d'},
      {"command" => 'a\\b',
       shared_dir => 1},
      {"command" => 'a\\b',
       shared_dir => 1,
       wd => 'c\\d'},
      {"command" => 'a\\b',
       nested => 1},
      {"command" => 'a\\b',
       nested => 1,
       wd => 'c\\d'},
      {"command" => 'a\\b',
       nested => 1,
       shared_dir => 1},
      {"command" => 'a\\b',
       nested => 1,
       shared_dir => 1,
       wd => 'c\\d'},
      {"command" => 'a\\b',
       nested => {envs => ['AB', 'X\\Y']},
       shared_dir => 1,
       wd => 'c\\d'},
      {"command" => 'a\\b',
       nested => {envs => ['AB', 'X\\Y']},
       shared_dir => 1,
       wd => 'c\\d',
       background => 1},
    ],
  }} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        "mkdir -p /drone/src/local/ciconfig",
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'mkdir -p `cat /drone/src/local/ciconfig/dockershareddir`',
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        q{perl -e 'print "ciconfig-" . rand' > /drone/src/local/ciconfig/dockername},
        q{docker run --name `cat /drone/src/local/ciconfig/dockername` -v `cat /drone/src/local/ciconfig/dockershareddir`:`cat /drone/src/local/ciconfig/dockershareddir` -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp -d -t quay.io/wakaba/droneci-step-base bash}
      ]
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'a\\b',
        'a\\b',
        'bash -c cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b',
        'bash -c cd\\ \\`cat\\ \\/drone\\/src\\/local\\/ciconfig\\/dockershareddir\\`\\ \\&\\&\\ a\\\\b',
        'bash -c cd\\ \\`cat\\ \\/drone\\/src\\/local\\/ciconfig\\/dockershareddir\\`\\ \\&\\&\\ cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b',
        'docker exec -t `cat /drone/src/local/ciconfig/dockername` bash -c a\\\\b',
        'docker exec -t `cat /drone/src/local/ciconfig/dockername` bash -c cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b',
        'docker exec -t `cat /drone/src/local/ciconfig/dockername` bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\\ \\&\\&\\ a\\\\b',
        'docker exec -t `cat /drone/src/local/ciconfig/dockername` bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\\ \\&\\&\\ cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b',
        'docker exec -t -e AB=$AB -e X\\Y=$X\\Y `cat /drone/src/local/ciconfig/dockername` bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\\ \\&\\&\\ cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b',
        'docker exec -t -e AB=$AB -e X\\Y=$X\\Y `cat /drone/src/local/ciconfig/dockername` bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\\ \\&\\&\\ cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b &',
      ],
      depends_on => [qw(build)],
    }, {
      name => 'cleanup-nested',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'docker stop `cat /drone/src/local/ciconfig/dockername`',
        'rm -fr `cat /drone/src/local/ciconfig/dockershareddir`',
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }],
    volumes => [{
      name => 'dockersock',
      host => {path => '/var/run/docker.sock'},
    }, {
      name => 'dockershareddir',
      host => {path => '/var/lib/docker/shareddir'},
    }],
  }}}, 'droneci docker nested commands'],
  [{droneci => {
    docker => {nested => 1},
    tests => [
      {"command" => 'a\\b', run_timeout => 3},
      {"command" => 'a\\b', run_timeout => 3,
       background => 1},
      {"command" => 'a\\b',
       wd => 'c\\d', run_timeout => 3},
      {"command" => 'a\\b',
       shared_dir => 1, run_timeout => 3},
      {"command" => 'a\\b',
       shared_dir => 1,
       wd => 'c\\d', run_timeout => 3},
      {"command" => 'a\\b',
       nested => 1, run_timeout => 3},
      {"command" => 'a\\b',
       nested => 1,
       wd => 'c\\d', run_timeout => 3},
      {"command" => 'a\\b',
       nested => 1,
       shared_dir => 1, run_timeout => 3},
      {"command" => 'a\\b',
       nested => 1,
       shared_dir => 1,
       wd => 'c\\d', run_timeout => 3},
      {"command" => 'a\\b',
       nested => {envs => ['AB', 'X\\Y']},
       shared_dir => 1,
       wd => 'c\\d', run_timeout => 3},
      {"command" => 'a\\b',
       nested => {envs => ['AB', 'X\\Y']},
       shared_dir => 1,
       wd => 'c\\d',
       background => 1, run_timeout => 3},
    ],
  }} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        "mkdir -p /drone/src/local/ciconfig",
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'mkdir -p `cat /drone/src/local/ciconfig/dockershareddir`',
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        q{perl -e 'print "ciconfig-" . rand' > /drone/src/local/ciconfig/dockername},
        q{docker run --name `cat /drone/src/local/ciconfig/dockername` -v `cat /drone/src/local/ciconfig/dockershareddir`:`cat /drone/src/local/ciconfig/dockershareddir` -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp -d -t quay.io/wakaba/droneci-step-base bash}
      ]
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'timeout 3 bash -c a\\\\b',
        'timeout 3 bash -c a\\\\b &',
        'timeout 3 bash -c cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b',
        'timeout 3 bash -c cd\\ \\`cat\\ \\/drone\\/src\\/local\\/ciconfig\\/dockershareddir\\`\\ \\&\\&\\ a\\\\b',
        'timeout 3 bash -c cd\\ \\`cat\\ \\/drone\\/src\\/local\\/ciconfig\\/dockershareddir\\`\\ \\&\\&\\ cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b',
        'docker exec -t `cat /drone/src/local/ciconfig/dockername` timeout 3 bash -c a\\\\b',
        'docker exec -t `cat /drone/src/local/ciconfig/dockername` timeout 3 bash -c cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b',
        'docker exec -t `cat /drone/src/local/ciconfig/dockername` timeout 3 bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\\ \\&\\&\\ a\\\\b',
        'docker exec -t `cat /drone/src/local/ciconfig/dockername` timeout 3 bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\\ \\&\\&\\ cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b',
        'docker exec -t -e AB=$AB -e X\\Y=$X\\Y `cat /drone/src/local/ciconfig/dockername` timeout 3 bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\\ \\&\\&\\ cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b',
        'docker exec -t -e AB=$AB -e X\\Y=$X\\Y `cat /drone/src/local/ciconfig/dockername` timeout 3 bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\\ \\&\\&\\ cd\\ c\\\\\\\\d\\ \\&\\&\\ a\\\\b &',
      ],
      depends_on => [qw(build)],
    }, {
      name => 'cleanup-nested',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'docker stop `cat /drone/src/local/ciconfig/dockername`',
        'rm -fr `cat /drone/src/local/ciconfig/dockershareddir`',
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }],
    volumes => [{
      name => 'dockersock',
      host => {path => '/var/run/docker.sock'},
    }, {
      name => 'dockershareddir',
      host => {path => '/var/lib/docker/shareddir'},
    }],
  }}}, 'droneci docker nested commands timeout'],
  [{droneci => {tests => [
    "aaa"
  ], cleanup => [
    "foo bar",
    "baz"
  ]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }],
  }}}, 'droneci build cleanup'],
  [{droneci => {
    docker => {nested => 1},
    tests => ['a'],
    cleanup => {
      "a" => {commands => ["x"], after_nested => 1},
      "b" => {commands => ["y"]},
    },
  }} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        "mkdir -p /drone/src/local/ciconfig",
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'mkdir -p `cat /drone/src/local/ciconfig/dockershareddir`',
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        q{perl -e 'print "ciconfig-" . rand' > /drone/src/local/ciconfig/dockername},
        q{docker run --name `cat /drone/src/local/ciconfig/dockername` -v `cat /drone/src/local/ciconfig/dockershareddir`:`cat /drone/src/local/ciconfig/dockershareddir` -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp -d -t quay.io/wakaba/droneci-step-base bash}
      ]
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'a',
      ],
      depends_on => [qw(build)],
    }, {
      name => 'cleanup--b',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'y',
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }, {
      name => 'cleanup-nested',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'docker stop `cat /drone/src/local/ciconfig/dockername`',
        'rm -fr `cat /drone/src/local/ciconfig/dockershareddir`',
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default cleanup--b)],
    }, {
      name => 'cleanup--a',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'x',
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default cleanup--b cleanup-nested)],
    }],
    volumes => [{
      name => 'dockersock',
      host => {path => '/var/run/docker.sock'},
    }, {
      name => 'dockershareddir',
      host => {path => '/var/lib/docker/shareddir'},
    }],
  }}}, 'droneci docker nested cleanup'],
  [{droneci => {tests => [
    "aaa"
  ], failed => ["x"], cleanup => [
    "foo bar",
    "baz"
  ]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'failed--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x"
      ],
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default failed--default)],
    }],
  }}}, 'droneci build failed'],
  [{droneci => {tests => [
    "aaa"
  ], failed => {"a" => ["x"], "b" => ["y"]}, cleanup => [
    "foo bar",
    "baz"
  ]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x"
      ],
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }, {
      name => 'failed--b',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "y"
      ],
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default
                        failed--a failed--b)],
    }],
  }}}, 'droneci build failed rules'],
  [{droneci => {tests => {"a" => {
    "commands" => [
      "aaa"
    ],
    "failed" => ["x"],
  }}, cleanup => [
    "foo bar",
    "baz"
  ]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'failed-test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x"
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      depends_on => [qw(test--a)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--a
                        failed-test--a)],
    }],
  }}}, 'droneci test-failed'],
  [{droneci => {tests => {"a" => {
    "commands" => [
      "aaa"
    ],
    "failed" => ["x"],
  }}, cleanup => [
    "foo bar",
    "baz"
  ],
    artifacts => {s3_bucket=>"ab",s3_prefix=>"f/",web_prefix=>"x:/"},
  }} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'mkdir -p /drone/src/local/ciconfig',
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/build',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--a',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "aaa",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'failed-test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--a',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "x",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      depends_on => [qw(test--a)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--a
                        failed-test--a)],
    }],
  }}}, 'droneci test-failed artifacts'],
  [{droneci => {tests => {"a" => {
    "commands" => [
      "aaa"
    ],
    "cleanup" => ["y"],
  }}, cleanup => [
    "foo bar",
    "baz"
  ],
    artifacts => {s3_bucket=>"ab",s3_prefix=>"f/",web_prefix=>"x:/"},
  }} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'mkdir -p /drone/src/local/ciconfig',
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/build',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--a',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "aaa",
        "y",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'failed-test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--a',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "y",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      depends_on => [qw(test--a)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--a
                        failed-test--a)],
    }],
  }}}, 'droneci test-cleanup'],
  [{droneci => {tests => {"a" => {
    "commands" => [
      "aaa"
    ],
    "failed" => ["x"],
    "cleanup" => ["y"],
  }}, cleanup => [
    "foo bar",
    "baz"
  ],
    artifacts => {s3_bucket=>"ab",s3_prefix=>"f/",web_prefix=>"x:/"},
  }} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'mkdir -p /drone/src/local/ciconfig',
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/build',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--a',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "aaa",
        "y",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'failed-test--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--a',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "x",
        "y",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--a/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      depends_on => [qw(test--a)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--a
                        failed-test--a)],
    }],
  }}}, 'droneci test-failed-cleanup'],
  [{droneci => {build => ["x"], tests => [
    "aaa"
  ], cleanup => [
    "foo bar",
    "baz"
  ],
    artifacts => {s3_bucket=>"ab",s3_prefix=>"f/",web_prefix=>"x:/"},
  }} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'mkdir -p /drone/src/local/ciconfig',
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/build',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        
        "x",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--default',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "aaa",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }],
  }}}, 'droneci build cleanup artifacts'],
  [{droneci => {build => ["x"], tests => [
    "aaa"
  ], failed => [
    "foo bar",
    "baz"
  ],
    artifacts => {s3_bucket=>"ab",s3_prefix=>"f/",web_prefix=>"x:/"},
  }} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'mkdir -p /drone/src/local/ciconfig',
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/build',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "x",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--default',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "aaa",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'failed--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/failed--default',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "foo bar",
        "baz",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed--default && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed--default/>"',
      ],
      when => {
        status => ['failure'],
      },
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }],
  }}}, 'droneci build cleanup artifacts'],
  [{droneci => {build => ["x"], tests => [
    "aaa"
  ], failed => [
    "foo bar",
    "baz"
  ],
    artifacts => {s3_bucket=>"ab",s3_prefix=>"f/",web_prefix=>"x:/",
                  sync_interval => 30},
  }} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'mkdir -p /drone/src/local/ciconfig',
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/build',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        q{while [ true ]; do aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build > /dev/null && echo '\\n'"Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build/>"; sleep 30; done &},
        "x",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--default',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        q{while [ true ]; do aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default > /dev/null && echo '\\n'"Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default/>"; sleep 30; done &},
        "aaa",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'failed--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/failed--default',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        q{while [ true ]; do aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed--default > /dev/null && echo '\\n'"Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed--default/>"; sleep 30; done &},
        "foo bar",
        "baz",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed--default && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed--default/>"',
      ],
      when => {
        status => ['failure'],
      },
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }],
  }}}, 'droneci build cleanup artifacts and sync_interval'],
  [{droneci => {
    docker => {nested => 1},
    artifacts => {s3_bucket=>"ab",s3_prefix=>"f/",web_prefix=>"x:/"},
    build => ["x"],
    tests => ['a'],
    cleanup => {
      "b" => {commands => ["y"]},
    },
  }} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        "mkdir -p /drone/src/local/ciconfig",
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/build',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        q{perl -e 'print "ciconfig-" . rand' > /drone/src/local/ciconfig/dockername},
        q{docker run --name `cat /drone/src/local/ciconfig/dockername` -v `cat /drone/src/local/ciconfig/dockershareddir`:`cat /drone/src/local/ciconfig/dockershareddir` -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp -d -t quay.io/wakaba/droneci-step-base bash},
        "x",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--default',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        'a',
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default/>"',
      ],
      depends_on => [qw(build)],
    }, {
      name => 'cleanup--b',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'y',
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }, {
      name => 'cleanup-nested',
      image => 'quay.io/wakaba/droneci-step-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }, {
        name => 'dockershareddir',
        path => '/var/lib/docker/shareddir',
      }],
      commands => [
        'bash -c cd\ \\\\\/app\ \&\&\ perl\ local\/bin\/pmbp\.pl\ \-\-install\-commands\ docker',
        'docker stop `cat /drone/src/local/ciconfig/dockername`',
        'rm -fr `cat /drone/src/local/ciconfig/dockershareddir`',
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default cleanup--b)],
    }],
    volumes => [{
      name => 'dockersock',
      host => {path => '/var/run/docker.sock'},
    }, {
      name => 'dockershareddir',
      host => {path => '/var/lib/docker/shareddir'},
    }],
  }}}, 'droneci docker nested cleanup artifacts'],
  [{droneci => {tests => [
    "aaa"
  ], deploy => [
    "foo bar",
    "baz"
  ], "failed" => {"a" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    "branch" => "c",
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => ['build'],
    }, {
      name => 'deploy--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz",
      ],
      depends_on => [qw(build test--default)],
      when => {branch => ['master'], event => ['push']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      failure => 'ignore',
      depends_on => [qw(build test--default deploy--default)],
      when => {status => ['failure']},
    }],
  }}}, 'droneci deploy'],
  [{droneci => {tests => [
    "aaa"
  ], deploy => {"a" => {"commands" => [
    "foo bar",
    "baz"
  ], "branch" => "ab"}, "b" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    "branch" => "c",
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => ['build'],
    }, {
      name => 'deploy--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz",
      ],
      depends_on => [qw(build test--default)],
      when => {branch => ['ab'], event => ['push']},
    }, {
      name => 'deploy--b',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      depends_on => [qw(build test--default)],
      when => {branch => ['c', 'xb', 'yb'], event => ['push']},
    }],
  }}}, 'droneci deploy branches'],
  [{droneci => {tests => [
    "aaa"
  ], deploy => {"b" => {"commands" => [
    "foo bar",
  ], "buildless" => 1}, "c" => {"commands" => [
    "baz",
  ], "testless" => 1}}, "failed" => {"a" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    "branch" => "c",
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => ['build'],
    }, {
      name => 'deploy--b',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
      ],
      depends_on => [],
      when => {branch => ['master'], event => ['push']},
    }, {
      name => 'deploy--c',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "baz",
      ],
      depends_on => [qw(build)],
      when => {branch => ['master'], event => ['push']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      failure => 'ignore',
      depends_on => [qw(build test--default deploy--b deploy--c)],
      when => {status => ['failure']},
    }],
  }}}, 'droneci buildless testless deploy'],
  [{droneci => {tests => [
    "aaa"
  ], make_deploy_branches => ["a", "bb"], "failed" => {"a" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    "branch" => "c",
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => ['build'],
    }, {
      name => 'deploy-make--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "make deploy-a",
      ],
      depends_on => ['build', 'test--default'],
      when => {branch => ['a'], event => ['push']},
    }, {
      name => 'deploy-make--bb',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "make deploy-bb",
      ],
      depends_on => [qw(build test--default)],
      when => {branch => ['bb'], event => ['push']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      failure => 'ignore',
      depends_on => [qw(build test--default deploy-make--a deploy-make--bb)],
      when => {status => ['failure']},
    }],
  }}}, 'droneci make_deploy_branches'],
  [{droneci => {tests => [
    "aaa"
  ], make_deploy_branches => [{"name"=>"a","buildless"=>1},
                              {"name"=>"bb","testless"=>1}],
                "failed" => {"a" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    "branch" => "c",
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => ['build'],
    }, {
      name => 'deploy-make--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "make deploy-a",
      ],
      depends_on => [],
      when => {branch => ['a'], event => ['push']},
    }, {
      name => 'deploy-make--bb',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "make deploy-bb",
      ],
      depends_on => ['build'],
      when => {branch => ['bb'], event => ['push']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      failure => 'ignore',
      depends_on => [qw(build test--default deploy-make--a deploy-make--bb)],
      when => {status => ['failure']},
    }],
  }}}, 'droneci make_deploy_branches less'],
  [{droneci => {tests => [
    "aaa"
  ], make_deploy_branches => [{"name"=>"a","buildless"=>1},
                              {"name"=>"bb","testless"=>1, awscli=>1}],
                "failed" => {"a" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    "branch" => "c",
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => ['build'],
    }, {
      name => 'deploy-make--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "make deploy-a",
      ],
      depends_on => [],
      when => {branch => ['a'], event => ['push']},
    }, {
      name => 'deploy-make--bb',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "make deploy-bb",
      ],
      depends_on => ['build'],
      when => {branch => ['bb'], event => ['push']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      failure => 'ignore',
      depends_on => [qw(build test--default deploy-make--a deploy-make--bb)],
      when => {status => ['failure']},
    }],
  }}}, 'droneci make_deploy_branches awscli'],
  [{droneci => {tests => [
    "aaa"
  ], make_deploy_branches => [{
    "name"=>"bb","nested"=>{
      envs => ['A'],
    },
    awscli=>1,
    shared_dir => 1, wd => 'foop',
  }]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => ['build'],
    }, {
      name => 'deploy-make--bb',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'docker exec -t -e A=$A `cat /drone/src/local/ciconfig/dockername` bash -c ' . quotemeta (
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version"
                ),
        'docker exec -t -e A=$A `cat /drone/src/local/ciconfig/dockername` bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\ \&\&\ cd\ foop\ \&\&\ make\ deploy\-bb',
      ],
      depends_on => ['build', 'test--default'],
      when => {branch => ['bb'], event => ['push']},
    }],
  }}}, 'droneci make_deploy_branches nested'],
  [{droneci => {tests => [
    "aaa"
  ], make_deploy_branches => [{
    "name"=>"bb","nested"=>{
      envs => ['A'],
    },
    secrets => ['X', 'Y'],
    shared_dir => 1, wd => 'foop',
  }]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => ['build'],
    }, {
      name => 'deploy-make--bb',
      image => 'quay.io/wakaba/droneci-step-base',
      environment => {
        X => {from_secret => 'X'},
        Y => {from_secret => 'Y'},
      },
      commands => [
        'docker exec -t -e A=$A `cat /drone/src/local/ciconfig/dockername` bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\ \&\&\ cd\ foop\ \&\&\ make\ deploy\-bb',
      ],
      depends_on => ['build', 'test--default'],
      when => {branch => ['bb'], event => ['push']},
    }],
  }}}, 'droneci make_deploy_branches secrets'],
  [{droneci => {tests => [
    "aaa"
  ], notification => {
    type => 'ikachan',
    url_prefix => q<https://foo.test/>,
    channel => q<#foo>,
  }, failed => ["x"], cleanup => [
    "foo bar",
    "baz"
  ]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'failed--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x"
      ],
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }, {
      name => 'failed-notification',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        q{curl -f -d message=Test\\ failed\\:\\ $DRONE_COMMIT_BRANCH\\ \\<$DRONE_BUILD_LINK\\> -d channel=\#foo https\\:\\/\\/foo\\.test\\/notice},
      ],
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default failed--default
                        failed-notification)],
    }],
  }}}, 'droneci notification'],
  [{droneci => {tests => [
    "aaa"
  ], notification => {
    type => 'ikachan',
    url_prefix => q<https://foo.test/>,
    channel => q<#foo>,
  }, artifacts => {s3_bucket=>"ab",s3_prefix=>"f/",web_prefix=>"x:/"},
  failed => ["x"], cleanup => [
    "foo bar",
    "baz"
  ]}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'mkdir -p /drone/src/local/ciconfig',
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/build',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--default',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "aaa",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default/>"',
      ],
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'failed--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/failed--default',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        "x",
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed--default && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed--default/>"',
      ],
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      environment => {
        AWS_ACCESS_KEY_ID => {from_secret => 'AWS_ACCESS_KEY_ID'},
        AWS_SECRET_ACCESS_KEY => {from_secret => 'AWS_SECRET_ACCESS_KEY'},
      },
      depends_on => [qw(build test--default)],
    }, {
      name => 'failed-notification',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/failed-notification',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && (sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || (sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;\n".
                 "aws --version",
        q{curl -f -d message=Test\\ failed\\:\\ $DRONE_COMMIT_BRANCH\\ \\<$DRONE_BUILD_LINK\\>'\\n'\<x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/build/\\>'\\n'\<x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/test--default/\\>'\\n'\<x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed--default/\\> -d channel=\#foo https\\:\\/\\/foo\\.test\\/notice},
        'aws s3 sync $CIRCLE_ARTIFACTS s3://ab/f/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed-notification && echo "Artifacts: <x:/$DRONE_REPO/$DRONE_BUILD_NUMBER-$DRONE_COMMIT_SHA/failed-notification/>"',
      ],
      when => {
        status => ['failure'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
      },
      failure => 'ignore',
      depends_on => [qw(build test--default failed--default
                        failed-notification)],
    }],
  }}}, 'droneci notification'],
  [{droneci => {tests => [
    "aaa"
  ], merger => \1, "failed" => {"a" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    "branch" => "c",
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => ['build'],
    }, {
      name => 'deploy-merger--nightly',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "git rev-parse HEAD > head.txt",
        q{curl -f -s -S --request POST --header "Authorization:token $GH_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\"base\":\"master\",\"head\":\"`cat head.txt`\",\"commit_message\":\"auto-merge $DRONE_COMMIT_BRANCH into master\"}" "https://api.github.com/repos/$DRONE_REPO/merges"},
      ],
      environment => {
        GH_ACCESS_TOKEN => {from_secret => 'GH_ACCESS_TOKEN'},
      },
      depends_on => ['build', 'test--default'],
      when => {branch => ['nightly'], event => ['push']},
    }, {
      name => 'deploy-merger--staging',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "git rev-parse HEAD > head.txt",
        q{curl -f -s -S --request POST --header "Authorization:token $GH_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\"base\":\"master\",\"head\":\"`cat head.txt`\",\"commit_message\":\"auto-merge $DRONE_COMMIT_BRANCH into master\"}" "https://api.github.com/repos/$DRONE_REPO/merges"},
      ],
      environment => {
        GH_ACCESS_TOKEN => {from_secret => 'GH_ACCESS_TOKEN'},
      },
      depends_on => [qw(build test--default)],
      when => {branch => ['staging'], event => ['push']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      failure => 'ignore',
      depends_on => [qw(build test--default deploy-merger--nightly
                        deploy-merger--staging)],
      when => {status => ['failure']},
    }],
  }}}, 'droneci merger'],
  [{droneci => {tests => [
    "aaa"
  ], merger => {into => 'ho-ge'}, "failed" => {"a" => {
    "commands" => ["x"],
    "branches" => ["xb", "yb"],
    "branch" => "c",
  }}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => ['build'],
    }, {
      name => 'deploy-merger--nightly',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "git rev-parse HEAD > head.txt",
        q{curl -f -s -S --request POST --header "Authorization:token $GH_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\"base\":\"ho-ge\",\"head\":\"`cat head.txt`\",\"commit_message\":\"auto-merge $DRONE_COMMIT_BRANCH into ho-ge\"}" "https://api.github.com/repos/$DRONE_REPO/merges"},
      ],
      environment => {
        GH_ACCESS_TOKEN => {from_secret => 'GH_ACCESS_TOKEN'},
      },
      depends_on => ['build', 'test--default'],
      when => {branch => ['nightly'], event => ['push']},
    }, {
      name => 'deploy-merger--staging',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "git rev-parse HEAD > head.txt",
        q{curl -f -s -S --request POST --header "Authorization:token $GH_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\"base\":\"ho-ge\",\"head\":\"`cat head.txt`\",\"commit_message\":\"auto-merge $DRONE_COMMIT_BRANCH into ho-ge\"}" "https://api.github.com/repos/$DRONE_REPO/merges"},
      ],
      environment => {
        GH_ACCESS_TOKEN => {from_secret => 'GH_ACCESS_TOKEN'},
      },
      depends_on => [qw(build test--default)],
      when => {branch => ['staging'], event => ['push']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "x",
      ],
      failure => 'ignore',
      depends_on => [qw(build test--default deploy-merger--nightly
                        deploy-merger--staging)],
      when => {status => ['failure']},
    }],
  }}}, 'droneci merger'],
  [{droneci => {cleanup => {hoge => {commands => [
    "foo bar",
    "baz"
  ], volumes => ["/a/b", "/a/c"]}}}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [],
      when => {branch => []},
    }, {
      name => 'cleanup--hoge',
      image => 'quay.io/wakaba/droneci-step-base',
      commands => [
        "foo bar",
        "baz"
      ],
      when => {
        status => ['failure', 'success'],
        branch => [],
      },
      volumes => [{
        name => "/a/b", path => "/a/b",
      }, {
        name => "/a/c", path => "/a/c",
      }],
      failure => 'ignore',
      depends_on => [qw(build)],
    }],
    volumes => [{
      name => "/a/b", host => {path => "/a/b"},
    }, {
      name => "/a/c", host => {path => "/a/c"},
    }],
  }}}, 'droneci docker volumes'],
) {
  my ($input, $expected, $name) = @$_;
  for (qw(.travis.yml circle.yml .circleci/config.yml .drone.yml
          .github/.touch
          .github/workflows/test.yml
          .github/workflows/hook.yml
          .github/workflows/pages.yml
          .github/workflows/cron.yml)) {
    $expected->{$_} ||= {remove => 1};
  }
  test {
    my $c = shift;
    my $path = path (__FILE__)->parent->parent->child ('t_deps/data');
    my $output = Main->generate ($input, $path, input_length => length perl2json_bytes_for_record $input);
    #use Test::Differences;
    #eq_or_diff $output, $expected;
    is_deeply $output, $expected;
    #use Data::Dumper;
    #warn Dumper $output;
    done $c;
  } n => 1, name => $name;
}

run_tests;

=head1 LICENSE

Copyright 2018-2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
