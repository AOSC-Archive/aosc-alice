// def variants = ['stub', 'container', 'base', 'buildkit', 'i3wm', 'gnome', 'kde', 'lxde', 'xfce', 'mate', 'cinnamon']
def variants = ['container', 'base', 'buildkit']
// uncomment below for future usage
// def arch = ['amd64', 'armel', 'arm64', 'ppc', 'ppc64']
def envMap = variants.collectEntries {
    ["${it}": gen_stage(it)]
}

def gen_stage(env) {
  return {
    stage('create-' + env + '-image') {
      node {
        git branch: 'master', url: 'https://github.com/liushuyu/aosc-alice'
        sh './update-tarball.sh amd64 ' + env
        archiveArtifacts allowEmptyArchive: false, artifacts: 'dist/**', onlyIfSuccessful: true
        cleanWs()
      }
    }
  }
}

parallel envMap
