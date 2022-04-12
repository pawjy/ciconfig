package Main;
use strict;
use warnings;

sub shellquote ($) {
  my $s = shift;
  $s =~ s/([\\'])/\\$1/g;
  return "'$s'";
} # shellquote

sub install_awscli_command () {
  return join "\n",
        "(((sudo apt-cache search python-dev | grep ^python-dev) || ".
           "sudo apt-get update) && ".
         "(sudo apt-get install -y pip || sudo apt-get install -y python-dev)) || ".
        "(sudo apt-get update && (sudo apt-get install -y pip || sudo apt-get install -y python-dev));",
        "sudo pip install awscli --upgrade || sudo pip3 install awscli --upgrade;",
        "aws --version";
} # install_awscli_command

sub new_job () {
  return {
    ## <https://github.com/circleci/circleci-docs/blob/master/jekyll/_cci2/configuration-reference.md#available-machine-images>
    machine => {"image" => "ubuntu-2004:202101-01"},
    steps => [],
  };
} # new_job

sub circle_step ($;%) {
  my ($in, %args) = @_;

  if (ref $in eq 'HASH') {
    if (defined $in->{command}) {
      if (ref $in->{command} eq 'ARRAY') {
        $in->{command} = join "\n", @{$in->{command}};
      }
    } elsif (defined delete $in->{awscli}) {
      $in->{command} = install_awscli_command ();
    } else {
      keys %$in; # reset
      my $command = each %$in;
      $in = {%{$in->{$command}}, command => $command};
    }
  } else {
    $in = {command => $in};
  }

  my $command = $in->{command};
  for ($args{branch}, $in->{branch}) {
    $command = join "\n",
        q{if [ "${CIRCLE_BRANCH}" == }.(shellquote $_).q{ ]; then},
        q{true},
        $command,
        q{fi}
        if defined $_;
  }

  my $type = $args{deploy} ? 'deploy' : 'run';
  if (exists $in->{parallel} and not $in->{parallel} and
      not $type eq 'deploy') {
    $command = join "\n",
        q{if [ "${CIRCLE_NODE_INDEX}" == "0" ]; then},
        q{true},
        $command,
        q{fi};
  }
  
  my $v = {command => $command};
  $v->{background} = \1 if $in->{background};
  $v->{no_output_timeout} = $in->{timeout} . 's'
      if $in->{timeout};

  return {$type => $v};
} # circle_step

sub github_step ($) {
  my $input = shift;
  my $output = {};
  if (ref $input) {
    $output->{run} = $input->{run} // die "No |run|";
    for my $name (@{$input->{secrets} or []}) {
      $output->{env}->{$name} = sprintf q<${{ secrets.%s }}>, $name;
    }
  } else {
    $output->{run} = $input;
  }
  return $output;
} # github_step

sub droneci_step ($) {
  my ($input) = @_;
  my $outputs = [];
  if (ref $input) {
    if ($input->{awscli}) {
      $input->{command} = install_awscli_command;
    }
    my $cmd = $input->{command};
    die "No |command|" unless defined $cmd;
    if (defined $input->{run_timeout}) {
      $cmd = sprintf 'timeout %d %s',
          $input->{run_timeout},
          $cmd;
    }
    if (defined $input->{wd}) {
      $cmd = 'cd ' . (quotemeta $input->{wd}) . ' && ' . $cmd;
    }
    if ($input->{shared_dir}) {
      if ($input->{nested}) {
        my $cmd1 = q{cd };
        my $cmd2 = q{ && } . $cmd;
        $cmd = 'bash -c ' . (quotemeta $cmd1) . 
            q{`cat /drone/src/local/ciconfig/dockershareddir`} .
            (quotemeta $cmd2);
      } else {
        $cmd = 'cd `cat /drone/src/local/ciconfig/dockershareddir` && ' . $cmd;
        $cmd = 'bash -c ' . quotemeta $cmd;
      }
    } elsif ($input->{nested} or defined $input->{wd}) {
      $cmd = 'bash -c ' . quotemeta $cmd;
    }
    if ($input->{nested}) {
      my @cmd = ('docker exec -t');
      if (ref $input->{nested}) {
        for my $name (sort { $a cmp $b } @{$input->{nested}->{envs}}) {
          push @cmd, '-e ' . $name . q{=$} . $name;
        }
      }
      push @cmd, q(`cat /drone/src/local/ciconfig/dockername`), $cmd;
      $cmd = join ' ', @cmd;
    }
    $cmd .= ' &' if $input->{background};
    return $cmd;
  } else {
    return $input;
  }
} # droneci_step

my $Platforms = {
  travisci => {
    file => '.travis.yml',
    set => sub {
      my $json = $_[0];
      #unshift @{$json->{jobs}->{include} ||= []}, {stage => 'test'};

      if (delete $json->{_empty}) {
        for (qw(before_install install script)) {
          die "Both |empty| and non-empty rules are specified"
              if defined $json->{$_};
        }

        $json->{git}->{submodules} = \0;
        $json->{before_install} = 'true';
        $json->{install} = 'true';
        $json->{script} = 'true';
      }
    },
  },
  circleci => {
    file => '.circleci/config.yml',
    set => sub {
      my $json = $_[0];
      $json->{version} = 2;
      $json->{workflows}->{version} = 2;
      $json->{jobs} ||= {};
      if (delete $json->{_empty}) {
        for (qw(_build _test _deploy _deploy_jobs)) {
          die "Both |empty| and non-empty rules are specified"
              if defined $json->{$_};
        }
      } else {
        my $deploy_branches = {};
        my $test_jobs = [];

        my $loads = [];
        push @$loads, 'checkout';
        
        my $split_jobs = defined $json->{_build_generated_files};
        if ($split_jobs) {
          push @$loads, {"attach_workspace" => {"at" => "./"}};
          if (@{$json->{_build_generated_images} or []}) {
            for (@{$json->{_build_generated_images} or []}) {
              my $name = $_;
              $name =~ s{:}{/}g;
              push @$loads,
                  {"run" => {"command" => "docker load -i .ciconfigtemp/dockerimages/$name.tar"}};
            }
          }
        }
        # $loads
        my $stores = [];
        if ($split_jobs) {
          if (@{$json->{_build_generated_images} or []}) {
            for (@{$json->{_build_generated_images} or []}) {
              my $name = $_;
              $name =~ s{:}{/}g;
              my $dir = $name;
              $dir =~ s{[^/]+$}{};
              push @$stores,
                  {run => {command => 'mkdir -p .ciconfigtemp/dockerimages/'.$dir}};
              push @$stores,
                  {"run" => {"command" => "docker save -o .ciconfigtemp/dockerimages/$name.tar $_"}};
            }
          }
          push @$stores,
              {"persist_to_workspace" => {
                "root" => "./",
                "paths" => ['.ciconfigtemp', @{$json->{_build_generated_files}}],
              }};
        }
        # $stores

        my @build_job_name = qw(build);
        my @job_name = @build_job_name;
        if ($split_jobs) {
          push @job_name, map { 'test-' . $_ } sort { $a cmp $b } keys %{$json->{_test_jobs}};
          push @job_name, 'test' if defined $json->{_test};
        }
        for my $job_name (@job_name) {
          $json->{jobs}->{$job_name} = new_job;
          $json->{jobs}->{$job_name}->{environment}->{CIRCLE_ARTIFACTS} = '/tmp/circle-artifacts/' . $job_name;
          $json->{jobs}->{$job_name}->{steps} = [
            @$loads,
            circle_step ('mkdir -p $CIRCLE_ARTIFACTS'),
          ];
        }
        $json->{jobs}->{build}->{steps} = [
          'checkout',
          circle_step ('mkdir -p $CIRCLE_ARTIFACTS'),
        ];
        if (defined $json->{_build}) {
          push @{$json->{jobs}->{build}->{steps}}, map {
            circle_step ($_);
          } @{delete $json->{_build}};
        }
        if (defined $json->{_test}) {
          push @{$json->{jobs}->{$split_jobs ? 'test' : 'build'}->{steps}}, map {
            circle_step ($_);
          } @{$json->{_test}};
        }
        for (sort { $a cmp $b } keys %{$json->{_test_jobs}}) {
          my $job_name = 'test-' . $_;
          push @{$json->{jobs}->{$job_name}->{steps}}, map {
            circle_step ($_);
          } @{$json->{_test_preps} or []}, @{$json->{_test_jobs}->{$_}};
        }
        delete $json->{_test_preps};
        for my $job_name (@job_name) {
          push @{$json->{jobs}->{$job_name}->{steps}},
              {store_artifacts => {
                path => '/tmp/circle-artifacts/' . $job_name,
              }};
        }
        push @{$json->{jobs}->{build}->{steps}}, @$stores;
        if (keys %{$json->{_deploy} or {}}) {
          for my $branch (sort { $a cmp $b } keys %{$json->{_deploy} or {}}) {
            push @{$json->{jobs}->{$split_jobs ? 'test' : 'build'}->{steps}}, map {
              circle_step ($_, deploy => 1, branch => $branch);
            } @{$json->{_deploy}->{$branch}};
            $deploy_branches->{$branch} = 1;
          }
          delete $json->{_deploy};
        }
        delete $json->{_test_jobs};
        delete $json->{_test};

        $json->{workflows}->{build}->{jobs} = [];
        
        ## Deploy job executed before builds
        for my $branch_name (sort { $a cmp $b } keys %{$json->{_soon_deploy_jobs} or {}}) {
          my $job_name = 'soon_deploy_' . $branch_name;
          $json->{jobs}->{$job_name} = new_job;
          push @{$json->{jobs}->{$job_name}->{steps}},
              'checkout',
              map {
                circle_step ($_, deploy => 1);
              } @{$json->{_soon_deploy_jobs}->{$branch_name}};
          push @{$json->{workflows}->{build}->{jobs}}, {$job_name => {
            filters => {branches => {only => [$branch_name]}},
            context => ['deploy-context'],
          }};
        }

        ## Build jobs
        my $build_job = {};
        push @{$json->{workflows}->{build}->{jobs}}, {'build' => $build_job};
        
        ## Deploy job executed after builds
        for my $branch_name (sort { $a cmp $b } keys %{$json->{_early_deploy_jobs} or {}}) {
          my $job_name = 'early_deploy_' . $branch_name;
          $json->{jobs}->{$job_name} = new_job;
          push @{$json->{jobs}->{$job_name}->{steps}}, @$loads;
          push @{$json->{jobs}->{$job_name}->{steps}},
              map {
                circle_step ($_, deploy => 1);
              } @{$json->{_early_deploy_jobs}->{$branch_name}};
          my $edj = {
            requires => \@build_job_name,
            filters => {branches => {only => [$branch_name]}},
            context => ['deploy-context'],
          };
          push @{$json->{workflows}->{build}->{jobs}}, {$job_name => $edj};
        }
        my $test_requires = ['build'];
        if (keys %{$json->{_soon_deploy_jobs} or {}} or
            keys %{$json->{_early_deploy_jobs} or {}}) {
          my $job_name = 'before_tests';
          $json->{jobs}->{$job_name} = new_job;
          push @{$json->{jobs}->{$job_name}->{steps}}, circle_step ('true');
          my $btj = {
            requires => \@build_job_name,
          };
          push @{$json->{workflows}->{build}->{jobs}}, {$job_name => $btj};
          push @$test_jobs, $btj;
          push @$test_requires, $job_name;
        }
        delete $json->{_soon_deploy_jobs};
        delete $json->{_early_deploy_jobs};

        ## Test jobs
        for my $job_name (@job_name) {
          next if $job_name eq 'build';
          my $tj = {requires => $test_requires};
          push @{$json->{workflows}->{build}->{jobs}}, {$job_name => $tj};
          push @$test_jobs, $tj;
          if ($json->{_parallel}) {
            $json->{jobs}->{$job_name}->{parallelism} = $json->{_parallel};
          }
        } # $job_name
        if (not $split_jobs and $json->{_parallel}) {
          $json->{jobs}->{build}->{parallelism} = $json->{_parallel};
        }
        delete $json->{_parallel};

        ## Deploy job executed after tests
        for my $branch_name (sort { $a cmp $b } keys %{$json->{_deploy_jobs} or {}}) {
          my $job_name = 'deploy_' . $branch_name;
          $json->{jobs}->{$job_name} = new_job;
          push @{$json->{jobs}->{$job_name}->{steps}}, @$loads;
          push @{$json->{jobs}->{$job_name}->{steps}},
              map {
                circle_step ($_, deploy => 1);
              } @{$json->{_deploy_jobs}->{$branch_name}};
          push @{$json->{workflows}->{build}->{jobs}}, {$job_name => {
            requires => \@job_name,
            filters => {branches => {only => [$branch_name]}},
            context => ['deploy-context'],
          }};
          $deploy_branches->{$branch_name} = 1;
        }
        delete $json->{_deploy_jobs};

        if (defined $json->{_tested_branches}) {
          $deploy_branches->{$_} = 1 for @{$json->{_tested_branches}};
          my $branches = [sort { $a cmp $b } keys %$deploy_branches];
          for my $tj ($build_job, @$test_jobs) {
            $tj->{filters}->{branches}->{only} = $branches;
          }
        } # _tested_branches
        delete $json->{_tested_branches};
        
        delete $json->{_build_generated_files};
        delete $json->{_build_generated_images};
      }
    },
  },
  circleci1 => { # obsolete
    file => 'circle.yml',
    set => sub {
    },
  },
  github => {
    to_json_files => sub {
      my $input = shift;
      my $output = {};

      ## <https://docs.github.com/en/actions/learn-github-actions/workflow-syntax-for-github-actions>

      my $test_steps = [];
      for my $key (sort { $a cmp $b } keys %{$input->{_test_steps}}) {
        for (@{$input->{_test_steps}->{$key}}) {
          push @$test_steps, github_step $_;
        }
      }

      my $build_steps = [];
      for my $key (sort { $a cmp $b } keys %{$input->{_build_steps}}) {
        for (@{$input->{_build_steps}->{$key}}) {
          push @$build_steps, github_step $_;
        }
      }
      
      if (@$test_steps) {
        ## has similar
        my $json = $output->{'.github/workflows/test.yml'} = {};
        $json->{name} = 'test';
        $json->{on}->{push} = {};
        
        my $job = $json->{jobs}->{test} = {
          'runs-on' => 'ubuntu-latest',
          steps => [@$build_steps, @$test_steps],
        };
        if ($input->{_with_macos}) {
          $job->{'runs-on'} = '${{ matrix.os }}';
        }

        if (1) { # artifacts
          my $artifacts_path = '/tmp/circle-artifacts/' . $json->{name};
          $json->{jobs}->{test}->{env}->{CIRCLE_ARTIFACTS} = $artifacts_path;

          unshift @{$job->{steps}},
              (github_step 'mkdir -p $CIRCLE_ARTIFACTS');

          ## <https://github.com/actions/upload-artifact>
          push @{$job->{steps}},
              {uses => 'actions/upload-artifact@v3',
               with => {path => $artifacts_path}};
        } # artifacts
        
        unshift @{$job->{steps}},
            {"uses" => 'actions/checkout@v2'};

        my $matrix = [{experimental => \0}];
        my $matrix_touched = 0;
        my $extend_matrix = sub {
          my ($name, $values) = @_;
          my @new;
          for my $old (@$matrix) {
            push @new, map {
              {%$old, $name => $_};
            } @$values;
          }
          $matrix = \@new;
          $matrix_touched = 1;
        };
        if (defined $input->{_perl_versions}) {
          if (delete $input->{_with_macos}) {
            $extend_matrix->('perl_version', $input->{_perl_versions});
            $extend_matrix->('os' => ['ubuntu-latest', 'macos-latest']);
            if ($input->{_with_macos_latest_perl}) {
              for (@$matrix) {
                if ($_->{perl_version} ne 'latest' and
                    $_->{os} eq 'macos-latest') {
                  $_->{experimental} = \1;
                }
              }
            }
          } else { # linux only
            $extend_matrix->('perl_version', $input->{_perl_versions});
          }
          $json->{jobs}->{test}->{strategy}->{matrix}->{include} = $matrix;
          $json->{jobs}->{test}->{env}->{PMBP_PERL_VERSION} = '${{ matrix.perl_version }}';
        } else { # no perl version
          if (delete $input->{_with_macos}) {
            $extend_matrix->('os', ['ubuntu-latest', 'macos-latest']);
          }
        } # perl version?

        for my $name (sort { $a cmp $b } keys %{$input->{_env_matrix}}) {
          my $values = $input->{_env_matrix}->{$name};
          $extend_matrix->('env_' . $name, $values);
          $json->{jobs}->{test}->{env}->{$name} = '${{ matrix.env_'.$name.' }}';
        }
        delete $json->{_env_matrix};

        for my $v (@{$input->{_matrix_allow_failure} or []}) {
          for my $m (@$matrix) {
            my $matched = 1;
            for (keys %$v) {
              unless ($m->{$_} eq $v->{$_}) {
                $matched = 0;
              }
            }
            if ($matched) {
              $m->{experimental} = \1;
            }
          }
        } # allow failure

        if ($matrix_touched) {
          $job->{strategy}->{matrix}->{include} = $matrix;
          $job->{strategy}->{'fail-fast'} = \0;
          $job->{'continue-on-error'} = '${{ matrix.experimental }}';
        }
      } elsif (@$build_steps) {
        die "There are no test steps while there are build steps";
      }
      
      for my $branch_name (keys %{$input->{_branch_github_deploy_jobs} or {}}) {
        ## has similar
        my $json = $output->{'.github/workflows/test.yml'} ||= {};
        $json->{name} = 'test';
        $json->{on}->{push} = {};

        my $job = $json->{jobs}->{'deploy_github_' . $branch_name} = {
          if => q[${{ github.ref == 'refs/heads/].$branch_name.q[' }}],
          'runs-on' => 'ubuntu-latest',
          steps => [map { github_step $_ } @{$input->{_branch_github_deploy_jobs}->{$branch_name} or []}],
        };

        if (defined $json->{jobs}->{test}) {
          push @{$job->{needs} ||= []}, 'test';
        }

        ## <https://docs.github.com/en/actions/learn-github-actions/workflow-syntax-for-github-actions#jobsjob_idpermissions>
        ## <https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token>
        $job->{permissions}->{contents} = 'write';
      }

      for my $branch_name (keys %{$input->{_branch_github_batch_jobs} or {}}) {
        ## has similar
        my $json = $output->{'.github/workflows/cron.yml'} ||= {};
        $json->{name} = 'cron';
        my $hour = int ($input->{_random_day_time} / 60);
        my $minute = ($input->{_random_day_time}) % 60;
        $json->{on}->{schedule} = [{cron => "$minute $hour * * *"}];

        my $job = $json->{jobs}->{'batch_github_' . $branch_name} = {
          if => q[${{ github.ref == 'refs/heads/].$branch_name.q[' }}],
          'runs-on' => 'ubuntu-latest',
          steps => [map { github_step $_ } @{$input->{_branch_github_batch_jobs}->{$branch_name} or []}],
        };

        unshift @{$job->{steps}},
            {"uses" => 'actions/checkout@v2',
             with => {token => q{${{ secrets.GH_ACCESS_TOKEN }}}}};
      }

      return $output;
    },
    possible_files => [
      '.github/workflows/test.yml',
      '.github/workflows/cron.yml',
    ],
  },
  droneci => {
    file => '.drone.yml',
    set => sub {
      my $json = $_[0];

      ## <https://docs.drone.io/pipeline/overview/>
      ## <https://docs.drone.io/yaml/docker/>

      $json->{kind} = 'pipeline';
      $json->{type} = 'docker';
      $json->{name} = 'default';
      $json->{workspace}->{path} = '/drone/src';

      my $volumes = [];
      my $init_commands = [];
      my $terminate_commands = [];
      my $step_names = {build => ['build']};
      my $group_step_names = {};
      my $build_branches = {};
      my $no_build_branch = 0;
      my $all_branches = {};
      my $no_all_branch = 0;
      my $insert_step = sub {
        my ($rules, %args) = @_;
        my $other_rules = [];
        for my $rule (sort { $a->{name} cmp $b->{name} } @$rules) {
          if ($args{before_nested} and $rule->{after_nested}) {
            push @$other_rules, $rule;
            next;
          } elsif ($args{buildless} and not $rule->{buildless}) {
            push @$other_rules, $rule;
            next;
          } elsif ($args{testless} and not $rule->{testless}) {
            push @$other_rules, $rule;
            next;
          }
          my $step = {};
          push @{$json->{steps} ||= []}, $step;
          $step->{name} = $rule->{name};
          $step->{image} = 'quay.io/wakaba/droneci-step-base';
          $step->{commands} = [];
          if ($args{phase} eq 'test') {
            $step->{environment}->{CIRCLE_NODE_TOTAL} = "1";
            $step->{environment}->{CIRCLE_NODE_INDEX} = "0";
          }
          $step->{when}->{status} = ['failure', 'success']
              if $args{phase} eq 'cleanup1' or
                 $args{phase} eq 'cleanup2' or
                 $args{phase} eq 'cleanup3';
          $step->{when}->{status} = ['failure']
              if $args{phase} eq 'failed';
          $step->{failure} = 'ignore'
              if $args{phase} eq 'cleanup1' or
                 $args{phase} eq 'cleanup2' or
                 $args{phase} eq 'cleanup3' or
                 $args{phase} eq 'failed';
          push @{$step_names->{$args{phase}} ||= []}, $step->{name};
          $step->{depends_on} = [map { @{$step_names->{$_} or []} } @{$args{prev_phases} or []}];
          if (defined $rule->{group}) {
            push @{$step->{depends_on}}, @{$group_step_names->{$rule->{group}} or []};
            push @{$group_step_names->{$rule->{group}} ||= []}, $step->{name};
          }
          my $found = {};
          $step->{depends_on} = [grep { not $found->{$_}++ } @{$step->{depends_on}}];

          my @r_command = @{$rule->{commands} or []};
          my @r_failed = @{$rule->{failed} or []};
          if (@{$rule->{cleanup} or []}) {
            push @r_command, @{$rule->{cleanup}};
            push @r_failed, @{$rule->{cleanup}};
          }

          my $fstep = {};
          if (@r_failed) {
            push @{$json->{steps} ||= []}, $fstep;
            $fstep->{name} = 'failed-' . $step->{name};
            $fstep->{image} = 'quay.io/wakaba/droneci-step-base';
            $fstep->{commands} = [];
            if ($args{phase} eq 'test') {
              $fstep->{environment}->{CIRCLE_NODE_TOTAL} = "1";
              $fstep->{environment}->{CIRCLE_NODE_INDEX} = "0";
            }
            $fstep->{when}->{status} = ['failure'];
            $fstep->{failure} = 'ignore';
            push @{$step_names->{$args{phase}} ||= []}, $fstep->{name};
            $fstep->{depends_on} = [$step->{name}];
            if (defined $rule->{group}) {
              push @{$group_step_names->{$rule->{group}} ||= []}, $fstep->{name};
            }
          } # failed

          for (@{$rule->{secrets} or []}, keys %{$args{secrets} or {}}) {
            $step->{environment}->{$_} = {from_secret => $_};
            $fstep->{environment}->{$_} = {from_secret => $_};
          }

          my $dep_build = ! $args{buildless} && !! grep { $_ eq 'build' } @{$step->{depends_on}};
          if (defined $rule->{branches}) {
            $fstep->{when}->{branch} =
            $step->{when}->{branch} = [sort { $a cmp $b } @{$rule->{branches}}];
            if ($dep_build) {
              $build_branches->{$_} = 1 for @{$rule->{branches}};
            }
            $all_branches->{$_} = 1 for @{$rule->{branches}};
          } elsif ($args{phase} eq 'cleanup1' or
                   $args{phase} eq 'cleanup2' or
                   $args{phase} eq 'cleanup3' or
                   $args{phase} eq 'failed') {
            if (not $no_all_branch) {
              $step->{when}->{branch} = [sort { $a cmp $b } keys %$all_branches];
            }
          } else {
            $no_build_branch = 1 if $dep_build;
            $no_all_branch = 1;
          }

          if ($args{phase} eq 'deploy') {
            $step->{when}->{event} = ['push'];
          }

          push @{$step->{commands}},
              map { map { droneci_step $_ } $_->($step->{name}) } @$init_commands;
          push @{$step->{commands}}, map { droneci_step $_ } @r_command;
          push @{$step->{commands}},
              map { map { droneci_step $_ } $_->($step->{name}) } @$terminate_commands;

          if (defined $fstep->{name}) {
            push @{$fstep->{commands}},
                map { map { droneci_step $_ } $_->($step->{name}) } @$init_commands;
            push @{$fstep->{commands}}, map { droneci_step $_ } @r_failed;
            push @{$fstep->{commands}},
                map { map { droneci_step $_ } $_->($step->{name}) } @$terminate_commands;
          }
          
          push @{$step->{volumes} ||= []}, @$volumes if @$volumes;
          push @{$fstep->{volumes} ||= []}, @$volumes if @$volumes;
        } # $rule
        return $other_rules;
      }; # $insert_step
      
      my $bstep = {};
      push @{$json->{steps} ||= []}, $bstep;
      $bstep->{name} = 'build';
      $bstep->{image} = 'quay.io/wakaba/droneci-step-base';
      $bstep->{commands} = [];

      my $bcommands = [];
      my $with_artifacts = delete $json->{_artifacts};
      my $aurls = [];
      my $cleanup_rules = [];
      my $secrets = {};
      if (my $dd = delete $json->{_docker}) {
        push @$volumes, {
          name => 'dockersock',
          path => '/var/run/docker.sock',
        };
        push @{$json->{volumes} ||= []}, {
          name => 'dockersock',
          host => {path => '/var/run/docker.sock'},
        };

        if ($dd->{with_shared_dir}) {
          push @$volumes, {
            name => 'dockershareddir',
            path => '/var/lib/docker/shareddir',
          };
          push @{$json->{volumes} ||= []}, {
            name => 'dockershareddir',
            host => {path => '/var/lib/docker/shareddir'},
          };
          push @{$bstep->{commands}}, map { droneci_step $_ }
              'mkdir -p /drone/src/local/ciconfig',
              q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir};
          unless ($with_artifacts) {
            push @{$bstep->{commands}}, map { droneci_step $_ }
                'mkdir -p `cat /drone/src/local/ciconfig/dockershareddir`';
          }
        } else { # shared dir
          if ($with_artifacts) {
            push @{$bstep->{commands}}, map { droneci_step $_ }
                'mkdir -p /drone/src/local/ciconfig',
                q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir};
          }
        } # shared dir
        
        push @$init_commands, sub { return {
          command => 'perl local/bin/pmbp.pl --install-commands docker',
          wd => '/app',
        } };

        if ($dd->{with_nested}) {
          push @$bcommands,
              q{perl -e 'print "ciconfig-" . rand' > /drone/src/local/ciconfig/dockername},
              'docker run --name `cat /drone/src/local/ciconfig/dockername` -v `cat /drone/src/local/ciconfig/dockershareddir`:`cat /drone/src/local/ciconfig/dockershareddir` -v /var/run/docker.sock:/var/run/docker.sock -v /tmp:/tmp -d -t quay.io/wakaba/droneci-step-base bash';

          push @$cleanup_rules, {name => 'cleanup-nested', commands => []};
          push @{$cleanup_rules->[-1]->{commands}},
              'docker stop `cat /drone/src/local/ciconfig/dockername`',
              'rm -fr `cat /drone/src/local/ciconfig/dockershareddir`';
        }
      } else { # not _docker
        if ($with_artifacts) {
          push @{$bstep->{commands}},
              'mkdir -p /drone/src/local/ciconfig',
              q{perl -e 'print "/var/lib/docker/shareddir/" . rand' > /drone/src/local/ciconfig/dockershareddir};
        }
      } # not _docker
      if ($with_artifacts) {
        push @$init_commands, sub {
          my $name = shift;
          return () if $name =~ /^cleanup-/;
          return (
            'export CIRCLE_ARTIFACTS=`cat /drone/src/local/ciconfig/dockershareddir`/artifacts/' . $name,
            'mkdir -p $CIRCLE_ARTIFACTS',
            {awscli => 1},
          );
        };
        push @$terminate_commands, sub {
          my $name = shift;
          return () if $name =~ /^cleanup-/;
          my $aurl = sprintf '%s$DRONE_REPO/$DRONE_BUILD_NUMBER/%s/',
              $with_artifacts->{web_prefix}, $name;
          push @$aurls, $aurl;
          return (
            (sprintf 'aws s3 sync $CIRCLE_ARTIFACTS s3://%s/%s$DRONE_REPO/$DRONE_BUILD_NUMBER/%s', $with_artifacts->{s3_bucket}, $with_artifacts->{s3_prefix}, $name),
            (sprintf 'echo "Artifacts: <%s>"', $aurl),
          );
        };
        $secrets->{AWS_ACCESS_KEY_ID} = 1;
        $secrets->{AWS_SECRET_ACCESS_KEY} = 1;
      } # $with_artifacts

      push @{$bstep->{commands}},
          map { map { droneci_step $_ } $_->('build') } @$init_commands;
      push @{$bstep->{commands}}, map { droneci_step $_ } @$bcommands;
      for (sort { $a cmp $b } keys %{$json->{_build_steps}}) {
        push @{$bstep->{commands}}, map {
          droneci_step $_;
        } @{$json->{_build_steps}->{$_}};
      }
      push @{$bstep->{commands}},
          map { map { droneci_step $_ } $_->('build') } @$terminate_commands;
      push @{$bstep->{volumes} ||= []}, @$volumes if @$volumes;
      delete $json->{_build_steps};

      for (keys %$secrets) {
        $bstep->{environment}->{$_} = {from_secret => $_};
      }

      {
        my $rules = delete $json->{_test_rules} || [];
        $rules = $insert_step->($rules, phase => 'test',
                                prev_phases => [qw(build)],
                                secrets => $secrets);
        die if @$rules;
      }

      {
        my $drules = delete $json->{_deploy_rules} || [];
        $drules = $insert_step->($drules, phase => 'deploy',
                                 prev_phases => [],
                                 buildless => 1,
                                 secrets => $secrets);
        $drules = $insert_step->($drules, phase => 'deploy',
                                 prev_phases => [qw(build)],
                                 testless => 1,
                                 secrets => $secrets);
        $drules = $insert_step->($drules, phase => 'deploy',
                                 prev_phases => [qw(build test)],
                                 secrets => $secrets);
        die if @$drules;
      }

      if (not $no_build_branch) {
        $bstep->{when}->{branch} = [sort { $a cmp $b } keys %$build_branches];
      }
      
      {
        my $rules = delete $json->{_failed_rules} || [];
        $rules = $insert_step->($rules, phase => 'failed',
                                prev_phases => [qw(build test deploy)],
                                secrets => $secrets);
        die if @$rules;
      }

      if (defined $json->{_notification}) {
        my $not = delete $json->{_notification};
        die unless $not->{type} eq 'ikachan';
        my $prefix = $not->{url_prefix};
        my $channel = $not->{channel};
        my $message = join '',
            (quotemeta 'Test failed: '),
            '$DRONE_COMMIT_BRANCH',
            (quotemeta ' <'),
            '$DRONE_BUILD_LINK',
            (quotemeta '>'),
            map {
              (
                (quotemeta "\x0A<"),
                $_,
                (quotemeta ">"),
              );
            } @$aurls;
        my $rules = [];
        push @$rules, {
          name => 'failed-notification',
          commands => [
            (sprintf 'curl -f -d message=%s -d channel=%s %snotice',
                 $message,
                 (quotemeta $channel),
                 (quotemeta $prefix)),
          ],
        };
        $rules = $insert_step->($rules, phase => 'failed',
                                prev_phases => [qw(build test deploy)]);
        die if @$rules;
      }

      {
        my $crules = delete $json->{_cleanup_rules} || [];
        $crules = $insert_step->($crules, phase => 'cleanup1',
                                 prev_phases => [qw(build test deploy failed)],
                                 before_nested => 1);
        
        my $cleanup_rules = $insert_step->($cleanup_rules,
                                           phase => 'cleanup2',
                                           prev_phases => [qw(build test
                                                              deploy failed
                                                              cleanup1)]);
        die if @$cleanup_rules;
        
        $crules = $insert_step->($crules, phase => 'cleanup3',
                                 prev_phases => [qw(build test deploy failed
                                                    cleanup1 cleanup2)]);
        die if @$crules;
      }
    }, # set
  },
}; # $Platforms

my $Options = {};

$Options->{'travisci', 'empty'} = {
  set => sub {
    return unless $_[1];
    $_[0]->{_empty} = 1;
  },
};

my $PerlVersions = {
  latest  => [qw(latest)],
  1       => [qw(latest 5.14.2 5.8.9)],
  '5.8+'  => [qw(latest 5.14.2 5.8.9)],
  '5.12+' => [qw(latest 5.14.2 5.12.4)],
  '5.10+' => [qw(latest 5.14.2 5.10.1)],
  '5.14+' => [qw(latest 5.14.2)],
};
my $LatestPerlVersion = '5.32.1';

$Options->{'travisci', 'pmbp'} = {
  set => sub {
    return unless $_[1];
    $_[0]->{git}->{submodules} = \0;
    $_[0]->{language} = 'perl';
    $_[0]->{perl} = [map { $_ eq 'latest' ? $LatestPerlVersion : $_ } @{$PerlVersions->{$_[1]} || die "Unknown |pmbp| value |$_[1]|"}];
    s/^(\d+\.\d+)\..+$/$1/ for @{$_[0]->{perl}};
    $_[0]->{before_install} = 'true';
    $_[0]->{install} = 'make test-deps';
    $_[0]->{script} = 'make test';
  },
};

$Options->{'github', 'pmbp'} = {
  set => sub {
    return unless $_[1];
    my $json = $_[0];
    $_[0]->{_perl_versions} = $PerlVersions->{$_[1]} || die "Unknown |pmbp| value |$_[1]|";
    push @{$json->{_build_steps}->{pmbp} ||= []}, 'make test-deps';
    push @{$json->{_test_steps}->{pmbp} ||= []}, 'make test';
  },
};

$Options->{'droneci', 'pmbp'} = {
  set => sub {
    return unless $_[1];
    my $json = $_[0];
    push @{$json->{_build_steps}->{pmbp} ||= []}, 'make test-deps';
    push @{$json->{_test_rules} ||= []}, {name => 'test-pmbp',
                                          commands => ['make test']};
  },
};

$Options->{'circleci', 'pmbp'} = {
  set => sub {
    return unless $_[1];
    my $json = $_[0];
    push @{$json->{_build} ||= []}, 'make test-deps';
    if (defined $json->{_build_generated_files}) {
      push @{$json->{_test_jobs}->{pmbp} ||= []}, 'make test';
    } else {
      push @{$json->{_test} ||= []}, 'make test';
    }
  },
};

$Options->{'github', 'macos'} = {
  set => sub {
    $_[0]->{_with_macos} = 1 if $_[1];
    if (ref $_[1] and $_[1]->{latest_perl_only}) {
      $_[0]->{_with_macos_latest_perl} = 1;
    }
  },
};

$Options->{'github', 'env_matrix'} = {
  set => sub {
    for my $name (keys %{$_[1] or {}}) {
      my $values = [@{$_[1]->{$name} or []}];
      $_[0]->{_env_matrix}->{$name} = $values;
    }
  },
};

$Options->{'github', 'matrix_allow_failure'} = {
  set => sub {
    push @{$_[0]->{_matrix_allow_failure} ||= []}, @{$_[1] or []};
  },
};

$Options->{'droneci', 'notification'} = {
  set => sub {
    return unless $_[1];
    if ($_[1]->{type} eq 'ikachan') {
      $_[0]->{_notification} = $_[1];
    } else {
      die "Unknown |notificaion| |type|: |$_[1]->{type}|";
    }
  },
};

$Options->{'travisci', 'notifications'} = {
  set => sub {
    return unless $_[1];
    die "Unknown |notificaions| value |$_[1]|" unless $_[1] eq 'suika';
    $_[0]->{notifications}->{email} = [qw(wakaba@suikawiki.org)];
    $_[0]->{notifications}->{irc}->{channels}
        = ['ircs://irc.suikawiki.org:6697#mechanize'];
    $_[0]->{notifications}->{irc}->{use_notice} = \1;
  },
};

$Options->{'travisci', 'merger'} = {
  set => sub {
    return unless $_[1];
    my $path = $_[2]->child ('config/travis-merger.txt');
    die "File |$path| not found" unless $path->is_file;
    $_[0]->{env}->{global}->{secure} = $path->slurp;
    push @{$_[0]->{jobs}->{include} ||= []},
        {stage => 'test'},
        {stage => 'merge',
         before_install => "true",
         install => "true",
         script => 'curl -f https://gist.githubusercontent.com/wakaba/ab553f86cd017e0cb28c6dbb5364b009/raw/travis-merge-job.pl | perl'};
  },
};

$Options->{'github', 'merger'} = {
  set => sub {
    my $json = $_[0];
    return unless $_[1];
    my $into = 'master';
    if (ref $_[1] eq 'HASH') {
      $into = $_[1]->{into} if defined $_[1]->{into};
    }
    for my $branch (qw(staging nightly)) {
      ## <https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables>
      push @{$json->{_branch_github_deploy_jobs}->{$branch} ||= []},
          {run => 'curl -f -s -S --request POST --header "Authorization:token $GITHUB_TOKEN" --header "Content-Type:application/json" --data-binary "{\"base\":\"'.$into.'\",\"head\":\"$GITHUB_SHA\",\"commit_message\":\"auto-merge $GITHUB_REF into '.$into.'\"}" "https://api.github.com/repos/$GITHUB_REPOSITORY/merges"',
           secrets => ['GITHUB_TOKEN']},
          {run => 'curl -f https://$BWALL_TOKEN:@$BWALL_HOST/ping/merger.${GITHUB_REF/refs\\/heads\\//}/${GITHUB_REPOSITORY/\\//%2F} -X POST',
           secrets => ['BWALL_TOKEN', 'BWALL_HOST']};
    } # $branch
  },
};

$Options->{'circleci', 'merger'} = {
  set => sub {
    my $json = $_[0];
    return unless $_[1];
    my $into = 'master';
    if (ref $_[1] eq 'HASH') {
      $into = $_[1]->{into} if defined $_[1]->{into};
    }
    for my $branch (qw(staging nightly)) {
      push @{$json->{_deploy_jobs}->{$branch} ||= []}, join "\n",
          'git rev-parse HEAD > head.txt',
          'curl -f -s -S --request POST --header "Authorization:token $GITHUB_ACCESS_TOKEN" --header "Content-Type:application/json" --data-binary "{\"base\":\"'.$into.'\",\"head\":\"`cat head.txt`\",\"commit_message\":\"auto-merge $CIRCLE_BRANCH into '.$into.'\"}" "https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/merges" && curl -f https://$BWALL_TOKEN:@$BWALL_HOST/ping/merger.$CIRCLE_BRANCH/$CIRCLE_PROJECT_USERNAME%2F$CIRCLE_PROJECT_REPONAME -X POST';
    } # $branch
  },
};

$Options->{'circleci', 'heroku'} = {
  set => sub {
    return unless $_[1];
    my $has_bg = !! $_[0]->{_build_generated_files};
    
    push @{$has_bg ? $_[0]->{_deploy_jobs}->{master} ||= [] : $_[0]->{_build} ||= []}, join "\n",
        'git config --global user.email "temp@circleci.test"',
        'git config --global user.name "CircleCI"';
    
    my $def = ref $_[1] eq 'HASH' ? $_[1] : {};
    push @{$_[0]->{$has_bg ? '_deploy_jobs' : '_deploy'}->{'master'} ||= []},
        'git checkout --orphan herokucommit && git commit -m "Heroku base commit"',
        @{ref $def->{prepare} eq 'ARRAY' ? $def->{prepare} : []},
        'make '.($has_bg ? 'create-commit-for-heroku-circleci' : 'create-commit-for-heroku'),
        'git push git@heroku.com:'.($def->{app_name} || '$HEROKU_APP_NAME').'.git +`git rev-parse HEAD`:refs/heads/master',
        @{ref $def->{pushed} eq 'ARRAY' ? $def->{pushed} : []},
    ;
  },
};

$Options->{'circleci', 'build_generated_files'} = {
  set => sub {
    return unless $_[1] and ref $_[1] eq 'ARRAY';
    push @{$_[0]->{_build_generated_files} ||= []}, @{$_[1]};
  },
};

$Options->{'circleci', 'build_generated_pmbp'} = {
  set => sub {
    return unless $_[1];
    push @{$_[0]->{_build_generated_files} ||= []},
        qw(deps local perl prove plackup lserver local-server rev);
  },
};

$Options->{'circleci', 'required_docker_images'} = {
  set => sub {
    return unless ref $_[1] eq 'ARRAY' and @{$_[1] or []};
    my $preps = [
        'docker info',
        {
          (join ' && ', map {
            "docker pull $_"
          } @{$_[1]}) => {
            background => 1,
          },
        },
    ];
    unshift @{$_[0]->{_build} ||= []}, @$preps;
    unshift @{$_[0]->{_test_preps} ||= []}, @$preps;
  }, # set
}; # required_docker_images

$Options->{'circleci', 'docker-build'} = {
  set => sub {
    return unless $_[1];
    my $defs = ref $_[1] eq 'ARRAY' ? $_[1] : [$_[1]];
    push @{$_[0]->{_build} ||= []}, 'docker info';
    my $has_bg = !! $_[0]->{_build_generated_files};
    my $has_login = {};
    for my $def (@$defs) {
      $def = ref $def ? $def : {name => $def};
      my $name = defined $def->{name} ? $def->{name} : $def->{expression};
      die "No |name|" unless defined $name;
      $def->{path} = '.' unless defined $def->{path};
      $def->{branch} = 'master' unless defined $def->{branch};
      if ($has_bg) {
        push @{$_[0]->{_build_generated_images} ||= []}, $name;
      }
      push @{$_[0]->{_build} ||= []},
          'docker build -t ' . $name . ' ' . $def->{path};

      next if $def->{no_push};
      if ($name =~ m{^([^/]+)/([^/]+)/([^/]+)$}) {
        if (not $has_login->{$1}) {
          push @{$_[0]->{$has_bg ? '_deploy_jobs' : '_deploy'}->{$def->{branch}} ||= []},
              'docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS '.$1.' || docker login -u $DOCKER_USER -p $DOCKER_PASS '.$1;
          $has_login->{$1} = 1;
        }
      } else {
        if (not $has_login->{''}) {
          push @{$_[0]->{$has_bg ? '_deploy_jobs' : '_deploy'}->{$def->{branch}} ||= []},
              'docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS || docker login -u $DOCKER_USER -p $DOCKER_PASS';
          $has_login->{''} = 1;
        }
      }

      push @{$_[0]->{$has_bg ? '_deploy_jobs' : '_deploy'}->{$def->{branch}} ||= []},
          'docker push ' . $name . ' && ' .
          'curl -sSLf $BWALL_URL'.(defined $def->{bwall_suffix} ? '.' . $def->{bwall_suffix} : $def->{branch} eq 'master' ? '' : '.' . $def->{branch}).' -X POST';
    } # $def
  },
};

$Options->{'github', 'build'} = {
  set => sub {
    if (ref $_[1] eq 'HASH') {
      for (keys %{$_[1]}) {
        push @{$_[0]->{_build_steps}->{$_} ||= []}, @{$_[1]->{$_}};
      }
    } else {
      push @{$_[0]->{_build_steps}->{default} ||= []}, @{$_[1]};
    }
  },
};

$Options->{'droneci', 'build'} = {
  set => sub {
    if (ref $_[1] eq 'HASH') {
      for (keys %{$_[1]}) {
        push @{$_[0]->{_build_steps}->{$_} ||= []}, @{$_[1]->{$_}};
      }
    } else {
      push @{$_[0]->{_build_steps}->{default} ||= []}, @{$_[1]};
    }
  },
};

$Options->{'circleci', 'build'} = {
  set => sub {
    push @{$_[0]->{_build} ||= []}, @{$_[1]};
  },
};

$Options->{'github', 'tests'} = {
  set => sub {
    if (ref $_[1] eq 'HASH') {
      for (keys %{$_[1]}) {
        push @{$_[0]->{_test_steps}->{$_} ||= []}, @{$_[1]->{$_}};
      }
    } else {
      push @{$_[0]->{_test_steps}->{default} ||= []}, @{$_[1]};
    }
  },
};

$Options->{'droneci', 'tests'} = {
  set => sub {
    my $steps = $_[1];
    if (not ref $steps eq 'HASH') {
      $steps = {default => $steps};
    }
    
    for (sort { $a cmp $b } keys %$steps) {
      my $rule = $steps->{$_};
      if (ref $rule eq 'ARRAY') {
        $rule = {commands => $rule};
      }
      if (defined $rule->{branch}) {
        push @{$rule->{branches} ||= []}, $rule->{branch};
      }
      push @{$_[0]->{_test_rules} ||= []}, {%$rule, name => 'test--' . $_};
    }
  },
};

$Options->{'circleci', 'tests'} = {
  set => sub {
    if (ref $_[1] eq 'HASH') {
      die "No |build_generated_files|"
          unless defined $_[0]->{_build_generated_files};
      for (sort { $a cmp $b } keys %{$_[1]}) {
        push @{$_[0]->{_test_jobs}->{$_} ||= []}, @{$_[1]->{$_}};
      }
    } else {
      push @{$_[0]->{_test} ||= []}, @{$_[1]};
    }
  },
};

$Options->{'circleci', 'tested_branches'} = {
  set => sub {
    push @{$_[0]->{_tested_branches} ||= []}, @{$_[1]};
  },
};

$Options->{'droneci', 'make_deploy_branches'} = {
  set => sub {
    for (@{$_[1]}) {
      my $x = $_;
      $x = {name => $x} unless ref $x eq 'HASH';
      my $branch = $x->{name};
      die "Bad name |$branch|" unless length $branch;
      push @{$_[0]->{_deploy_rules} ||= []}, {
        name => 'deploy-make--' . $branch,
        buildless => $x->{buildless},
        testless => $x->{testless},
        secrets => $x->{secrets},
        commands => [
          ($x->{awscli} ? {awscli => 1,
                           nested => $x->{nested}} : ()),
          {command => "make deploy-$branch",
           nested => $x->{nested},
           shared_dir => $x->{shared_dir},
           wd => $x->{wd}},
        ],
        branches => [$branch],
      };
    }
  },
};

$Options->{'circleci', 'make_deploy_branches'} = {
  set => sub {
    my $has_bg = !! $_[0]->{_build_generated_files};
    for (@{$_[1]}) {
      my $branch;
      my $buildless;
      my $testless;
      my $awscli;
      if (ref $_) {
        $branch = $_->{name};
        $buildless = $_->{buildless};
        $testless = $_->{testless} || $buildless;
        $awscli = $_->{awscli};
      } else {
        $branch = $_;
      }
      die "No |build_generated_files|" if $testless and not $has_bg;
      push @{$_[0]->{$testless ? $buildless ? '_soon_deploy_jobs' : '_early_deploy_jobs' : $has_bg ? '_deploy_jobs' : '_deploy'}->{$branch} ||= []},
          ($awscli ? {awscli => 1} : ()),
          "make deploy-$branch";
    }
  },
};

$Options->{'droneci', 'deploy'} = {
  set => sub {
    my $steps = $_[1];
    if (not ref $steps eq 'HASH') {
      $steps = {default => $steps};
    }
    
    for (sort { $a cmp $b } keys %$steps) {
      my $rule = $steps->{$_};
      if (ref $rule eq 'ARRAY') {
        $rule = {commands => $rule};
      }
      if (defined $rule->{branch}) {
        push @{$rule->{branches} ||= []}, $rule->{branch};
      }
      $rule->{branches} //= ['master'];
      push @{$_[0]->{_deploy_rules} ||= []}, {%$rule, name => 'deploy--' . $_};
    }
  },
};

$Options->{'circleci', 'deploy'} = {
  set => sub {
    my $def = $_[1];
    if (ref $_[1] eq 'ARRAY') {
      $def = {branch => 'master', commands => $_[1]};
    }
    my $has_bg = !! $_[0]->{_build_generated_files};
    push @{$_[0]->{$has_bg ? '_deploy_jobs' : '_deploy'}->{$def->{branch}} ||= []},
        @{$def->{commands}};
  },
};

$Options->{'circleci', 'deploy_branch'} = {
  set => sub {
    my $def = $_[1];
    my $has_bg = !! $_[0]->{_build_generated_files};
    for my $branch (sort { $a cmp $b } keys %$def) {
      push @{$_[0]->{$has_bg ? '_deploy_jobs' : '_deploy'}->{$branch} ||= []}, @{$def->{$branch}};
    }
  },
};

$Options->{'droneci', 'failed'} = {
  set => sub {
    my $steps = $_[1];
    if (not ref $steps eq 'HASH') {
      $steps = {default => $steps};
    }
    
    for (sort { $a cmp $b } keys %$steps) {
      my $rule = $steps->{$_};
      if (ref $rule eq 'ARRAY') {
        $rule = {commands => $rule};
      }
      push @{$_[0]->{_failed_rules} ||= []}, {%$rule,
                                              name => 'failed--' . $_,
                                              branches => undef};
    }
  },
};

$Options->{'droneci', 'cleanup'} = {
  set => sub {
    my $steps = $_[1];
    if (not ref $steps eq 'HASH') {
      $steps = {default => $steps};
    }
    
    for (sort { $a cmp $b } keys %$steps) {
      my $rule = $steps->{$_};
      if (ref $rule eq 'ARRAY') {
        $rule = {commands => $rule};
      }
      push @{$_[0]->{_cleanup_rules} ||= []}, {%$rule,
                                               name => 'cleanup--' . $_,
                                               branches => undef};
    }
  },
};

$Options->{'droneci', 'artifacts'} = {
  set => sub {
    return unless $_[1];
    $_[0]->{_artifacts} = $_[1];
  },
};

$Options->{'droneci', 'docker'} = {
  set => sub {
    return unless $_[1];
    $_[0]->{_docker} = {};
    if (ref $_[1]) {
      $_[0]->{_docker}->{with_shared_dir} = 1 if $_[1]->{nested};
      $_[0]->{_docker}->{with_nested} = 1 if $_[1]->{nested};
    }
  },
};

$Options->{'circleci', 'awscli'} = {
  set => sub {
    return unless $_[1];
    push @{$_[0]->{_build} ||= []}, install_awscli_command ();
  },
};

$Options->{'circleci', 'parallel'} = {
  set => sub {
    return unless $_[1];
    return if ref $_[1] eq 'SCALAR' and not ${$_[1]};
    my $value = 2;
    if (not ref $_[1]) {
      $value = 0+$_[1];
      $value = 2 if $value < 2;
    }
    $_[0]->{_parallel} = $value;
  },
};

$Options->{'circleci', 'empty'} = {
  set => sub {
    $_[0]->{_empty} = 1;
  },
};

$Options->{'circleci', 'gaa'} = {
  set => sub {
    my $json = $_[0];
    $json->{jobs}->{gaa4} = new_job;
    $json->{jobs}->{gaa4}->{steps} = [
        "checkout",
        circle_step (join ";",
          'git config --global user.email "temp@circleci.test"',
          'git config --global user.name "CircleCI"',
        ),
        circle_step ("make deps"),
        circle_step ("make updatenightly"),
        circle_step ("git diff-index --quiet HEAD --cached || git commit -m auto", deploy => 1),
        circle_step ("git push origin +`git rev-parse HEAD`:refs/heads/nightly", deploy => 1),
    ];
    my $hour = int ($json->{_random_day_time} / 60);
    my $minute = ($json->{_random_day_time}) % 60;
    $json->{workflows}->{gaa4} = {
      "jobs" => ["gaa4"],
      "triggers" => [
        {
          "schedule" => {
            "cron" => "$minute $hour * * *",
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
    };
  },
};

$Options->{'circleci', 'autobuild'} = {
  set => sub {
    my $json = $_[0];
    my $time = ($json->{_random_day_time} + 60*60) % (24*60);
    my $hour = int ($time / 60);
    my $minute = $time % 60;
    $json->{workflows}->{autobuild} = {
      "jobs" => ["build"],
      "triggers" => [
        {
          "schedule" => {
            "cron" => "$minute $hour * * *",
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
    };
  },
};

$Options->{'github', 'gaa'} = {
  set => sub {
    my $json = $_[0];
    push @{$json->{_branch_github_batch_jobs}->{master} ||= []},
        'git config --global user.email "temp@github.test"',
        'git config --global user.name "GitHub Actions"',
        "make deps",
        "make updatenightly",
        "git diff-index --quiet HEAD --cached || git commit -m auto",
        "git push origin +`git rev-parse HEAD`:refs/heads/nightly",
        ;
  },
};

sub generate ($$$;%) {
  my ($class, $input, $root_path, %args) = @_;

  my $data = {};
  my $random_day_time = ((($args{input_length} || 0) + 12*60 + 21)) % (24*60);

  for my $platform (sort { $a cmp $b } keys %$input) {
    my $p_def = $Platforms->{$platform};
    die "Unknown platform |$platform|" unless defined $p_def;
    my $json = {};
    local $json->{_random_day_time} = $random_day_time;

    for my $opt (sort { $a cmp $b } keys %{$input->{$platform}}) {
      my $o_def = $Options->{$platform, $opt};
      die "Unknown option |$platform|, |$opt|" unless defined $o_def;
      my $o_param = $input->{$platform}->{$opt};
      $o_def->{set}->($json, $o_param, $root_path);
    } # $opt

    if (defined $p_def->{to_json_files}) {
      my $files = $p_def->{to_json_files}->($json);
      for my $file_name (keys %$files) {
        $data->{$file_name} = {json => $files->{$file_name}};
      }
    } else {
      $p_def->{set}->($json);
      $data->{$p_def->{file}} = {json => $json};
    }
  } # $platform

  for my $platform (sort { $a cmp $b } keys %$Platforms) {
    my $p_def = $Platforms->{$platform};
    if (defined $p_def->{file}) {
      $data->{$p_def->{file}} ||= {remove => 1};
    }
    for (@{$p_def->{possible_files} or []}) {
      $data->{$_} ||= {remove => 1};
    }
  } # $platform

  return $data;
} # generate

1;

=head1 LICENSE

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
