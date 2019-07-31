#!groovy
/*
Welcome to the MoonShell Jenkinsfile

There are many ways to set up and define a Jenkinsfile, but a completely
declarative pipeline was chosen as it's simplest for people who are leveling
up bash to use.
*/

node {
    git_clone()
    setup()
    test()
}

def git_clone () {
    stage('Git Clone') {
        checkout scm
    }
}

def setup () {
    stage('Setup') {
        sh('bundle install')
    }
}

def test () {
    stage('Testing') {
        sh('printenv | sort')

        parallel (
            markdownlint: {
                sh('bundle exec mdl -v $(find . -name "*.md" -not -path "./vendor*")')
            },
            rubocop: {
                sh('bundle exec rubocop -D')
            },
            bashate: {
                // lint all files with a bash shebang
                sh('bashate -v -i E006,E042 $(grep -slIR "#\\!/.*bash$" . | grep -v "^./vendor")')
            }
        )
    }
}

