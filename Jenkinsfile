// Online Boutique DevSecOps — Jenkins declarative pipeline.
// Agents run as Kubernetes pods in namespace `boutique-ci`; images are built with Kaniko (no Docker socket).
// The service matrix is ci/services.yaml (single source of truth).
pipeline {
  agent {
    kubernetes {
      namespace 'boutique-ci'
      defaultContainer 'tools'
      yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-agent
  restartPolicy: Never
  containers:
    - name: jnlp
      image: jenkins/inbound-agent:3384.v60d89463d9e0-1
      args: ['${computer.jnlpmac} ${computer.name}']
      env:
        - name: JENKINS_URL
          value: "http://jenkins.jenkins.svc.cluster.local:8080/"
      resources:
        requests: {cpu: "100m", memory: "256Mi"}
        limits: {cpu: "500m", memory: "512Mi"}
    - name: tools
      image: python:3.14-alpine
      command: ['sleep']
      args: ['3600']
      resources:
        requests: {cpu: "50m", memory: "128Mi"}
        limits: {cpu: "500m", memory: "512Mi"}
    - name: gitleaks
      image: ghcr.io/gitleaks/gitleaks:v8.30.0
      command: ['sleep']
      args: ['3600']
      resources:
        requests: {cpu: "50m", memory: "128Mi"}
        limits: {cpu: "500m", memory: "512Mi"}
    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.23.2-debug
      command: ['sleep']
      args: ['3600']
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
      resources:
        requests: {cpu: "200m", memory: "512Mi"}
        limits: {cpu: "1500m", memory: "2Gi"}
  volumes:
    - name: docker-config
      secret:
        secretName: harbor-push
        items:
          - key: .dockerconfigjson
            path: config.json
'''
    }
  }

  parameters {
    string(name: 'SERVICE', defaultValue: 'frontend', description: 'Service to build (from ci/services.yaml)')
    booleanParam(name: 'FORCE_ALL', defaultValue: false, description: 'Build every service')
  }

  environment {
    REGISTRY = '192.168.1.8:30082/boutique'
    SRC_REGISTRY = 'us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo'
  }

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  stages {
    stage('1. Preflight') {
      steps {
        container('tools') {
          sh '''
            set -e
            echo "workspace=$WORKSPACE"
            git rev-parse --short HEAD
            python3 -c "print('python ok')"
          '''
        }
      }
    }

    stage('2. Change Detection') {
      steps {
        container('tools') {
          script {
            def changed = sh(script: 'bash ci/scripts/detect-changes.sh origin/devsecops || true', returnStdout: true).trim()
            env.CHANGED_SERVICES = changed.replace('\n', ',')
            echo "changed services: ${env.CHANGED_SERVICES ?: '(none)'}"
            def target = params.FORCE_ALL ? 'ALL' : (params.SERVICE ?: env.CHANGED_SERVICES)
            env.BUILD_TARGET = target
            echo "build target: ${target}"
          }
        }
      }
    }

    stage('3. Secret Scan (gitleaks)') {
      steps {
        container('gitleaks') {
          sh '''
            set -e
            gitleaks dir . --config .gitleaks.toml --redact --no-banner --exit-code 1
          '''
        }
      }
    }

    stage('4. Build & Push (Kaniko)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps {
        container('kaniko') {
          sh '''
            set -e
            SHA=$(git rev-parse --short HEAD)
            TAG="v0.10.6-${SHA}-b${BUILD_NUMBER}"
            for svc in $(echo "${BUILD_TARGET:-frontend}" | tr ',' ' '); do
              ctx="src/$svc"
              [ "$svc" = "cartservice" ] && ctx="src/cartservice/src"
              echo "== building $svc from $ctx =="
              /kaniko/executor \
                --context="dir://$WORKSPACE/$ctx" \
                --dockerfile="$WORKSPACE/$ctx/Dockerfile" \
                --destination="$REGISTRY/$svc:$TAG" \
                --digest-file="$WORKSPACE/digest-$svc.txt" \
                --cache=false --verbosity=info
              echo "$svc -> $REGISTRY/$svc:$TAG @ $(cat $WORKSPACE/digest-$svc.txt)"
            done
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'digest-*.txt', allowEmptyArchive: true
    }
  }
}
