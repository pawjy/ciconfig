use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Main;
use JSON::PS;

my $machine = {"image" => "ubuntu-2004:202101-01"};

for (
  [{} => {}],

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
    version => 2,
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
  [{circleci => {'docker-build' => 'abc/def'}} => {'.circleci/config.yml' => {json => {
    version => 2,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker build -t abc/def .'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} ."\x0Atrue\x0A" . 'docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS || docker login -u $DOCKER_USER -p $DOCKER_PASS' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} ."\x0Atrue\x0A" . 'docker push abc/def && curl -sSLf $BWALL_URL -X POST' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {'docker-build' => 'xyz/abc/def'}} => {'.circleci/config.yml' => {json => {
    version => 2,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => 'docker info'}},
        {run => {command => 'docker build -t xyz/abc/def .'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} ."\x0Atrue\x0A" . 'docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS xyz || docker login -u $DOCKER_USER -p $DOCKER_PASS xyz' . "\x0Afi"}},
        {deploy => {command => q{if [ "${CIRCLE_BRANCH}" == 'master' ]; then} ."\x0Atrue\x0A" . 'docker push xyz/abc/def && curl -sSLf $BWALL_URL -X POST' . "\x0Afi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {
    'docker-build' => 'xyz/abc/def',
    build_generated_files => [],
    tests => ['test1'],
  }} => {'.circleci/config.yml' => {json => {
    version => 2,
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
        {deploy => {command => 'docker push xyz/abc/def && curl -sSLf $BWALL_URL -X POST'}},
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
    version => 2,
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
        {deploy => {command => 'docker push xyz/$ABC/def:$CIRCLE_SHA1 && curl -sSLf $BWALL_URL -X POST'}},
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
    version => 2,
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
    version => 2,
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
        {deploy => {command => 'docker push xyz/abc/def && curl -sSLf $BWALL_URL -X POST'}},
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
  [{circleci => {required_docker_images => ['a/b', 'a/b/c']}} => {'.circleci/config.yml' => {json => {
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
        {deploy => {command => "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && sudo apt-get install -y python-dev) || (sudo apt-get update && sudo apt-get install -y python-dev)\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade\n".
                 "aws --version"}},
        {deploy => {command => 'make deploy-master'}},
      ],
    }, early_deploy_devel => {
      machine => $machine,
      steps => [
        'checkout',
        {"attach_workspace" => {"at" => "./"}},
        {deploy => {command => "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && sudo apt-get install -y python-dev) || (sudo apt-get update && sudo apt-get install -y python-dev)\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade\n".
                 "aws --version"}},
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
        {deploy => {command => 'git rev-parse HEAD > head.txt' . "\x0A" .
          'curl -f -s -S --request POST --header "Authorization:token $GITHUB_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\\"base\\":\\"master\\",\\"head\\":\\"`cat head.txt`\\",\\"commit_message\\":\\"auto-merge $CIRCLE_BRANCH into master\\"}" "https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/merges" && curl -f https://$BWALL_TOKEN:@$BWALL_HOST/ping/merger.$CIRCLE_BRANCH/$CIRCLE_PROJECT_USERNAME%2F$CIRCLE_PROJECT_REPONAME -X POST'}},
      ],
    }, deploy_nightly => {
      machine => $machine,
      steps => [
        'checkout',
        {deploy => {command => 'git rev-parse HEAD > head.txt' . "\x0A" .
          'curl -f -s -S --request POST --header "Authorization:token $GITHUB_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\\"base\\":\\"master\\",\\"head\\":\\"`cat head.txt`\\",\\"commit_message\\":\\"auto-merge $CIRCLE_BRANCH into master\\"}" "https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/merges" && curl -f https://$BWALL_TOKEN:@$BWALL_HOST/ping/merger.$CIRCLE_BRANCH/$CIRCLE_PROJECT_USERNAME%2F$CIRCLE_PROJECT_REPONAME -X POST'}},
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
    version => 2,
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
        {deploy => {command => 'git rev-parse HEAD > head.txt' . "\x0A" .
          'curl -f -s -S --request POST --header "Authorization:token $GITHUB_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\\"base\\":\\"dev\\",\\"head\\":\\"`cat head.txt`\\",\\"commit_message\\":\\"auto-merge $CIRCLE_BRANCH into dev\\"}" "https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/merges" && curl -f https://$BWALL_TOKEN:@$BWALL_HOST/ping/merger.$CIRCLE_BRANCH/$CIRCLE_PROJECT_USERNAME%2F$CIRCLE_PROJECT_REPONAME -X POST'}},
      ],
    }, deploy_nightly => {
      machine => $machine,
      steps => [
        'checkout',
        {deploy => {command => 'git rev-parse HEAD > head.txt' . "\x0A" .
          'curl -f -s -S --request POST --header "Authorization:token $GITHUB_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\\"base\\":\\"dev\\",\\"head\\":\\"`cat head.txt`\\",\\"commit_message\\":\\"auto-merge $CIRCLE_BRANCH into dev\\"}" "https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/merges" && curl -f https://$BWALL_TOKEN:@$BWALL_HOST/ping/merger.$CIRCLE_BRANCH/$CIRCLE_PROJECT_USERNAME%2F$CIRCLE_PROJECT_REPONAME -X POST'}},
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
    version => 2,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {run => {command => "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && sudo apt-get install -y python-dev) || (sudo apt-get update && sudo apt-get install -y python-dev)\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade\n".
                 "aws --version"}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {deploy_branch => {
    x => [{awscli => 1}],
  }}} => {'.circleci/config.yml' => {json => {
    version => 2,
    jobs => {build => {
      machine => $machine,
      environment => {CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/build'},
      steps => [
        'checkout',
        {run => {command => 'mkdir -p $CIRCLE_ARTIFACTS'}},
        {store_artifacts => {path => '/tmp/circle-artifacts/build'}},
        {deploy => {command => "if [ \"\${CIRCLE_BRANCH}\" == 'x' ]; then\ntrue\n(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && sudo apt-get install -y python-dev) || (sudo apt-get update && sudo apt-get install -y python-dev)\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade\n".
                 "aws --version\nfi"}},
      ],
    }},
    workflows => {version => 2, build => {jobs => [{'build'=>{}}]}},
  }}}],
  [{circleci => {parallel => \1}} => {'.circleci/config.yml' => {json => {
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
    jobs => {},
    workflows => {version => 2},
  }}}],
  [{circleci => {
    gaa => 1,
    empty => 1,
  }} => {'.circleci/config.yml' => {json => {
    version => 2,
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
            "cron" => "23 13 * * *",
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
    version => 2,
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
            "cron" => "4 13 * * *",
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
  [{circleci => {
    build_generated_files => [],
    parallel => 4,
    tests => ['test1'],
    tested_branches => ['b2', 'b1'],
  }} => {'.circleci/config.yml' => {json => {
    version => 2,
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
    version => 2,
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
    version => 2,
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
    version => 2,
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
  
  [{github => {pmbp => 'latest'}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      strategy => {matrix => {include => [{perl_version => 'latest'}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2'},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
  }}}],
  [{github => {pmbp => 1}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      strategy => {matrix => {include => [{perl_version => 'latest'},
                                          {perl_version => '5.14.2'},
                                          {perl_version => '5.8.9'}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2'},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
  }}}],
  [{github => {pmbp => '5.8+'}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      strategy => {matrix => {include => [{perl_version => 'latest'},
                                          {perl_version => '5.14.2'},
                                          {perl_version => '5.8.9'}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2'},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
  }}}],
  [{github => {pmbp => '5.10+'}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      strategy => {matrix => {include => [{perl_version => 'latest'},
                                          {perl_version => '5.14.2'},
                                          {perl_version => '5.10.1'}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2'},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
  }}}],
  [{github => {pmbp => '5.14+'}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      strategy => {matrix => {include => [{perl_version => 'latest'},
                                          {perl_version => '5.14.2'}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2'},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
  }}}],
  [{github => {merger => 1}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {deploy_github_nightly => {
      if => q{${{ github.ref == 'refs/heads/nightly' }}},
      'runs-on' => 'ubuntu-latest',
      permissions => {contents => 'write'},
      steps => [
        {run => 'curl -f -s -S --request POST --header "Authorization:token $GITHUB_TOKEN" --header "Content-Type:application/json" --data-binary "{\"base\":\"master\",\"head\":\"$GITHUB_SHA\",\"commit_message\":\"auto-merge $GITHUB_REF into master\"}" "https://api.github.com/repos/$GITHUB_REPOSITORY/merges"',
         env => {GITHUB_TOKEN => q<${{ secrets.GITHUB_TOKEN }}>}},
        {run => 'curl -f https://$BWALL_TOKEN:@$BWALL_HOST/ping/merger.${GITHUB_REF/refs\/heads\//}/${GITHUB_REPOSITORY/\//%2F} -X POST',
         env => {BWALL_TOKEN => q<${{ secrets.BWALL_TOKEN }}>,
                 BWALL_HOST => q<${{ secrets.BWALL_HOST }}>}},
      ],
    }, deploy_github_staging => {
      if => q{${{ github.ref == 'refs/heads/staging' }}},
      'runs-on' => 'ubuntu-latest',
      permissions => {contents => 'write'},
      steps => [
        {run => 'curl -f -s -S --request POST --header "Authorization:token $GITHUB_TOKEN" --header "Content-Type:application/json" --data-binary "{\"base\":\"master\",\"head\":\"$GITHUB_SHA\",\"commit_message\":\"auto-merge $GITHUB_REF into master\"}" "https://api.github.com/repos/$GITHUB_REPOSITORY/merges"',
         env => {GITHUB_TOKEN => q<${{ secrets.GITHUB_TOKEN }}>}},
        {run => 'curl -f https://$BWALL_TOKEN:@$BWALL_HOST/ping/merger.${GITHUB_REF/refs\/heads\//}/${GITHUB_REPOSITORY/\//%2F} -X POST',
         env => {BWALL_TOKEN => q<${{ secrets.BWALL_TOKEN }}>,
                 BWALL_HOST => q<${{ secrets.BWALL_HOST }}>}},
      ],
    }},
  }}}],
  [{github => {pmbp => 'latest',
               merger => 1}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => 'ubuntu-latest',
      strategy => {matrix => {include => [{perl_version => 'latest'}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2'},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'}},
      ],
    }, deploy_github_nightly => {
      if => q{${{ github.ref == 'refs/heads/nightly' }}},
      'runs-on' => 'ubuntu-latest',
      permissions => {contents => 'write'},
      needs => ['test'],
      steps => [
        {run => 'curl -f -s -S --request POST --header "Authorization:token $GITHUB_TOKEN" --header "Content-Type:application/json" --data-binary "{\"base\":\"master\",\"head\":\"$GITHUB_SHA\",\"commit_message\":\"auto-merge $GITHUB_REF into master\"}" "https://api.github.com/repos/$GITHUB_REPOSITORY/merges"',
         env => {GITHUB_TOKEN => q<${{ secrets.GITHUB_TOKEN }}>}},
        {run => 'curl -f https://$BWALL_TOKEN:@$BWALL_HOST/ping/merger.${GITHUB_REF/refs\/heads\//}/${GITHUB_REPOSITORY/\//%2F} -X POST',
         env => {BWALL_TOKEN => q<${{ secrets.BWALL_TOKEN }}>,
                 BWALL_HOST => q<${{ secrets.BWALL_HOST }}>}},
      ],
    }, deploy_github_staging => {
      if => q{${{ github.ref == 'refs/heads/staging' }}},
      'runs-on' => 'ubuntu-latest',
      permissions => {contents => 'write'},
      needs => ['test'],
      steps => [
        {run => 'curl -f -s -S --request POST --header "Authorization:token $GITHUB_TOKEN" --header "Content-Type:application/json" --data-binary "{\"base\":\"master\",\"head\":\"$GITHUB_SHA\",\"commit_message\":\"auto-merge $GITHUB_REF into master\"}" "https://api.github.com/repos/$GITHUB_REPOSITORY/merges"',
         env => {GITHUB_TOKEN => q<${{ secrets.GITHUB_TOKEN }}>}},
        {run => 'curl -f https://$BWALL_TOKEN:@$BWALL_HOST/ping/merger.${GITHUB_REF/refs\/heads\//}/${GITHUB_REPOSITORY/\//%2F} -X POST',
         env => {BWALL_TOKEN => q<${{ secrets.BWALL_TOKEN }}>,
                 BWALL_HOST => q<${{ secrets.BWALL_HOST }}>}},
      ],
    }},
  }}}],
  [{github => {gaa => 1}} => {'.github/workflows/cron.yml' => {json => {
    name => 'cron',
    on => {schedule => [{cron => '2 13 * * *'}]},
    jobs => {batch_github_master => {
      if => q{${{ github.ref == 'refs/heads/master' }}},
      'runs-on' => 'ubuntu-latest',
      steps => [
        {uses => 'actions/checkout@v2',
         with => {token => '${{ secrets.GH_ACCESS_TOKEN }}'}},
        {run => 'git config --global user.email "temp@github.test"'},
        {run => 'git config --global user.name "GitHub Actions"'},
        {run => 'make deps'},
        {run => 'make updatenightly'},
        {run => 'git diff-index --quiet HEAD --cached || git commit -m auto'},
        {run => 'git push origin +`git rev-parse HEAD`:refs/heads/nightly'},
      ],
    }},
  }}}],
  [{github => {pmbp => 'latest', macos => 1}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => '${{ matrix.os }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           os => 'ubuntu-latest'},
                                          {perl_version => 'latest',
                                           os => 'macos-latest'}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2'},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
  }}}, 'macos'],
  [{github => {pmbp => 'latest', macos => {latest_perl_only => 1}}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => '${{ matrix.os }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           os => 'ubuntu-latest'},
                                          {perl_version => 'latest',
                                           os => 'macos-latest'}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2'},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
  }}}, 'macos latest perl'],
  [{github => {pmbp => '5.14+', macos => {latest_perl_only => 1}}} => {'.github/workflows/test.yml' => {json => {
    name => 'test',
    on => {push => {}},
    jobs => {test => {
      'runs-on' => '${{ matrix.os }}',
      strategy => {matrix => {include => [{perl_version => 'latest',
                                           os => 'ubuntu-latest'},
                                          {perl_version => '5.14.2',
                                           os => 'ubuntu-latest'},
                                          {perl_version => 'latest',
                                           os => 'macos-latest'}]},
                   'fail-fast' => \0},
      env => {'PMBP_PERL_VERSION' => '${{ matrix.perl_version }}',
              CIRCLE_ARTIFACTS => '/tmp/circle-artifacts/test'},
      steps => [
        {uses => 'actions/checkout@v2'},
        {run => 'mkdir -p $CIRCLE_ARTIFACTS'},
        {run => 'make test-deps'},
        {run => 'make test'},
        {uses => 'actions/upload-artifact@v3',
         with => {path => '/tmp/circle-artifacts/test'}},
      ],
    }},
  }}}, 'macos latest perl + 5.14+'],
  
  [{droneci => {}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [],
    }],
  }}}, 'droneci empty'],
  [{droneci => {"pmbp" => 1}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "make test-deps",
      ],
    }, {
      name => 'test-pmbp',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "foo bar",
        "baz"
      ],
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "aaa",
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "aaa",
      ],
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "aaa",
      ],
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
  }}}, 'droneci build tests 2'],
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--a',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }],
      commands => [
        "bash -c cd\\ \\\\\\/app\\ \\&\\&\\ perl\\ local\\/bin\\/pmbp\\.pl\\ \\-\\-install\\-commands\\ docker",
      ],
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
        q{docker run --name `cat /drone/src/local/ciconfig/dockername` -v `cat /drone/src/local/ciconfig/dockershareddir`:`cat /drone/src/local/ciconfig/dockershareddir` -v /var/run/docker.sock:/var/run/docker.sock -d -t quay.io/wakaba/docker-perl-app-base bash},
      ],
    }, {
      name => 'cleanup-nested',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      volumes => [{
        name => 'dockersock',
        path => '/var/run/docker.sock',
      }],
      commands => [
        "bash -c cd\\ \\\\\\/app\\ \\&\\&\\ perl\\ local\\/bin\\/pmbp\\.pl\\ \\-\\-install\\-commands\\ docker",
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
        q{docker run --name `cat /drone/src/local/ciconfig/dockername` -v `cat /drone/src/local/ciconfig/dockershareddir`:`cat /drone/src/local/ciconfig/dockershareddir` -v /var/run/docker.sock:/var/run/docker.sock -d -t quay.io/wakaba/docker-perl-app-base bash}
      ]
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
        q{docker run --name `cat /drone/src/local/ciconfig/dockername` -v `cat /drone/src/local/ciconfig/dockershareddir`:`cat /drone/src/local/ciconfig/dockershareddir` -v /var/run/docker.sock:/var/run/docker.sock -d -t quay.io/wakaba/docker-perl-app-base bash}
      ]
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
  [{droneci => {build => ["x"], tests => [
    "aaa"
  ], cleanup => [
    "foo bar",
    "baz"
  ], artifacts => 1}} => {'.drone.yml' => {json => {
    kind => 'pipeline',
    type => 'docker',
    name => 'default',
    workspace => {path => '/drone/src'},
    steps => [{
      name => 'build',
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        'mkdir -p /drone/src/local/ciconfig',
        q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir},
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/build',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "x",
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--default',
        'mkdir -p $CIRCLE_ARTIFACTS',
        "aaa",
      ],
      environment => {
        CIRCLE_NODE_TOTAL => "1",
        CIRCLE_NODE_INDEX => "0",
      },
      depends_on => [qw(build)],
    }, {
      name => 'cleanup--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
  [{droneci => {
    docker => {nested => 1},
    artifacts => 1,
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
        q{perl -e 'print "ciconfig-" . rand' > /drone/src/local/ciconfig/dockername},
        q{docker run --name `cat /drone/src/local/ciconfig/dockername` -v `cat /drone/src/local/ciconfig/dockershareddir`:`cat /drone/src/local/ciconfig/dockershareddir` -v /var/run/docker.sock:/var/run/docker.sock -d -t quay.io/wakaba/docker-perl-app-base bash},
        "x",
      ]
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
        'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/test--default',
        'mkdir -p $CIRCLE_ARTIFACTS',
        'a',
      ],
      depends_on => [qw(build)],
    }, {
      name => 'cleanup--b',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "foo bar",
        "baz",
      ],
      depends_on => [qw(build test--default)],
      when => {branch => ['master']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "foo bar",
        "baz",
      ],
      depends_on => [qw(build test--default)],
      when => {branch => ['ab']},
    }, {
      name => 'deploy--b',
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "x",
      ],
      depends_on => [qw(build test--default)],
      when => {branch => ['c', 'xb', 'yb']},
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "foo bar",
      ],
      depends_on => [],
      when => {branch => ['master']},
    }, {
      name => 'deploy--c',
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "baz",
      ],
      depends_on => [qw(build)],
      when => {branch => ['master']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "make deploy-a",
      ],
      depends_on => ['build', 'test--default'],
      when => {branch => ['a']},
    }, {
      name => 'deploy-make--bb',
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "make deploy-bb",
      ],
      depends_on => [qw(build test--default)],
      when => {branch => ['bb']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "make deploy-a",
      ],
      depends_on => [],
      when => {branch => ['a']},
    }, {
      name => 'deploy-make--bb',
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "make deploy-bb",
      ],
      depends_on => ['build'],
      when => {branch => ['bb']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "make deploy-a",
      ],
      depends_on => [],
      when => {branch => ['a']},
    }, {
      name => 'deploy-make--bb',
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        "(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && sudo apt-get install -y python-dev) || (sudo apt-get update && sudo apt-get install -y python-dev)\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade\n".
                 "aws --version",
        "make deploy-bb",
      ],
      depends_on => ['build'],
      when => {branch => ['bb']},
    }, {
      name => 'failed--a',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
      ],
    }, {
      name => 'test--default',
      image => 'quay.io/wakaba/docker-perl-app-base',
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
      image => 'quay.io/wakaba/docker-perl-app-base',
      commands => [
        'docker exec -t -e A=$A `cat /drone/src/local/ciconfig/dockername` bash -c ' . quotemeta ("(((sudo apt-cache search python-dev | grep ^python-dev) || sudo apt-get update) && sudo apt-get install -y python-dev) || (sudo apt-get update && sudo apt-get install -y python-dev)\n".
                 "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade\n".
                 "aws --version"),
        'docker exec -t -e A=$A `cat /drone/src/local/ciconfig/dockername` bash -c cd\ `cat /drone/src/local/ciconfig/dockershareddir`\ \&\&\ cd\ foop\ \&\&\ make\ deploy\-bb',
      ],
      depends_on => ['build', 'test--default'],
      when => {branch => ['bb']},
    }],
  }}}, 'droneci make_deploy_branches nested'],
) {
  my ($input, $expected, $name) = @$_;
  for (qw(.travis.yml circle.yml .circleci/config.yml .drone.yml
          .github/workflows/test.yml
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

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
