#!groovy

node {
    git_clone()
    test_setup()
    test()
    copy()
    output()
}

def git_clone () {
    stage('Git Clone') {
        checkout scm
    }
}

def test_setup () {
    stage('Setup') {
        sh('bundle install')
    }
}

def test () {
    stage('Testing') {
        sh('printenv | sort')

        parallel markdownlint: {
            sh('mdl -v $(find . -name "*.md")')
        }, rubocop: {
            sh('rubocop -D')
        }, bashate: {
            sh('bashate -v -i E006,E042 $(find . -name "*.sh")')
        }
    }
}

def copy () {
    stage('Copy') {
        def DESTINATION = "${env.JENKINS_HOME}/sources/moonshell/${env.BRANCH_NAME}"
        sh("mkdir -p '${DESTINATION}'")
        sh("rsync -rvC '${env.WORKSPACE}/' '${DESTINATION}/' --delete-before --exclude='cds@tmp'")
    }
}

def output () {
    // ~/sources is maintained as a source of repositories that have passed
    // testing; this may not apply to other organisations.
    stage('Output') {
        def DESTINATION = "${env.JENKINS_HOME}/sources/moonshell/${env.BRANCH_NAME}"
        sh("git rev-parse HEAD | tr -d '\\n' > '${DESTINATION}/commit'")
        def GIT_COMMIT = readFile "${DESTINATION}/commit"
        echo "GIT_COMMIT=${GIT_COMMIT}"
    }
}
