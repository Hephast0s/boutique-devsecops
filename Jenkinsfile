// Online Boutique DevSecOps — Jenkins declarative pipeline.
// Agents: Kubernetes pods in namespace `boutique-ci`. Builds: Kaniko (no Docker socket).
// Supply chain: gitleaks -> Kaniko build -> Syft SBOM -> Trivy image scan -> cosign sign/attest -> verify.
// Service matrix: ci/services.yaml (single source of truth).
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
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
    - name: jnlp
      image: jenkins/inbound-agent:3384.v60d89463d9e0-1
      args: ['$(JENKINS_SECRET)', '$(JENKINS_NAME)']
      env:
        - name: JENKINS_URL
          value: "http://jenkins.jenkins.svc.cluster.local:8080/"
      resources: {requests: {cpu: "100m", memory: "256Mi"}, limits: {cpu: "500m", memory: "512Mi"}}
    - name: tools
      image: python:3.14.7-alpine@sha256:05b2b8b732ecd268fee8727a369f936f022d1321b59befd13c30ede22769dcdc
      command: ['sleep']
      args: ['3600']
      resources: {requests: {cpu: "50m", memory: "128Mi"}, limits: {cpu: "1000m", memory: "1Gi"}}
    - name: sign
      image: alpine:3.21@sha256:ce64758a109eb420d874a118f87920e625e12d3634e03b4a5573fd9f6e5d3507
      command: ['sleep']
      args: ['3600']
      env:
        - name: COSIGN_PASSWORD
          valueFrom: {secretKeyRef: {name: cosign-key, key: COSIGN_PASSWORD}}
        - name: DOCKER_CONFIG
          value: /dockercfg
      volumeMounts:
        - {name: cosign-key, mountPath: /cosign, readOnly: true}
        - {name: docker-config, mountPath: /dockercfg, readOnly: true}
      resources: {requests: {cpu: "20m", memory: "128Mi"}, limits: {cpu: "500m", memory: "512Mi"}}
    - name: gitleaks
      image: ghcr.io/gitleaks/gitleaks:v8.30.0
      command: ['sleep']
      args: ['3600']
      resources: {requests: {cpu: "50m", memory: "128Mi"}, limits: {cpu: "500m", memory: "512Mi"}}
    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.23.2-debug
      command: ['sleep']
      args: ['3600']
      volumeMounts: [{name: docker-config, mountPath: /kaniko/.docker}]
      resources: {requests: {cpu: "200m", memory: "512Mi"}, limits: {cpu: "1500m", memory: "2Gi"}}
    - name: trivy
      image: aquasec/trivy:0.74.0@sha256:62b1e65e8869bc4b4c6aa4fa2b21595256c7c2f6018a9d9ad61caf87187c1969
      command: ['sleep']
      args: ['3600']
      resources: {requests: {cpu: "50m", memory: "128Mi"}, limits: {cpu: "500m", memory: "1Gi"}}
    - name: semgrep
      image: semgrep/semgrep@sha256:acaac22ffc7b7cc5926de0751b223bce0b2491c33d18422fa72f632c78d81198
      command: ['sleep']
      args: ['3600']
      resources: {requests: {cpu: "50m", memory: "256Mi"}, limits: {cpu: "1000m", memory: "1Gi"}}
    - name: hadolint
      image: hadolint/hadolint@sha256:9a3944b7fddcb947d1ffd90829ac1a6e5c30479223358f249d8b96c7d0019e27
      command: ['sleep']
      args: ['3600']
      resources: {requests: {cpu: "20m", memory: "64Mi"}, limits: {cpu: "200m", memory: "256Mi"}}
    - name: golang
      image: golang:1.27.0-alpine
      command: ['sleep']
      args: ['3600']
      resources: {requests: {cpu: "50m", memory: "256Mi"}, limits: {cpu: "1000m", memory: "1Gi"}}
    - name: dotnet
      image: mcr.microsoft.com/dotnet/sdk:10.0.100-noble
      command: ['sleep']
      args: ['3600']
      resources: {requests: {cpu: "50m", memory: "256Mi"}, limits: {cpu: "1000m", memory: "1Gi"}}
  volumes:
    - name: docker-config
      secret: {secretName: harbor-push, items: [{key: .dockerconfigjson, path: config.json}]}
    - name: cosign-key
      secret: {secretName: cosign-key, items: [{key: cosign.key, path: cosign.key}]}
'''
    }
  }

  parameters {
    string(name: 'SERVICE', defaultValue: '', description: 'Service(s) to build, comma-separated (empty = auto-detect from changes; use FORCE_ALL for all)')
    booleanParam(name: 'FORCE_ALL', defaultValue: false, description: 'Build every service')
  }

  environment {
    REGISTRY = '192.168.1.8:30082/boutique'
  }

  options { buildDiscarder(logRotator(numToKeepStr: '10')); timeout(time: 45, unit: 'MINUTES') }

  stages {
    stage('1. Preflight') {
      steps {
        container('tools') {
          sh 'apk add --no-cache git bash syft=1.42.4-r2; git config --global --add safe.directory "*"'
          sh 'bash ci/scripts/test-build-target.sh'
          script { env.GIT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim() }
          echo "workspace=${WORKSPACE} git_sha=${env.GIT_SHA}"
        }
        container('sign') {
          sh 'apk add --no-cache cosign=2.4.1-r5'
        }
      }
    }

    stage('2. Change Detection') {
      steps { container('tools') { script {
        def changed = sh(script: 'bash ci/scripts/detect-changes.sh origin/main', returnStdout: true).trim()
        env.CHANGED_SERVICES = changed.replace('\n', ',')
        def allSvcs = sh(script: "grep -E '^  - name:' ci/services.yaml | sed 's/.*name: //' | paste -sd, -", returnStdout: true).trim()
        env.BUILD_TARGET = params.FORCE_ALL ? allSvcs : (params.SERVICE ?: env.CHANGED_SERVICES)
        if (env.BUILD_TARGET == '') {
          echo "No services to build (no changed services and no SERVICE/FORCE_ALL). This build does not exercise a pipeline."
          currentBuild.result = 'UNSTABLE'
        }
        echo "changed=${env.CHANGED_SERVICES ?: '(none)'} target=${env.BUILD_TARGET}"
      } } }
    }

    stage('3. Secret Scan (gitleaks)') {
      steps { container('gitleaks') {
        sh 'gitleaks dir . --config .gitleaks.toml --redact --no-banner --exit-code 1'
      } }
    }

    stage('3b. Dockerfile Lint (hadolint)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps { container('hadolint') {
        sh '''
          set -e
          for svc in $(echo "${BUILD_TARGET:-frontend}" | tr ',' ' '); do
            ctx="src/$svc"; [ "$svc" = "cartservice" ] && ctx="src/cartservice/src"
            echo "== hadolint $svc =="
            hadolint --failure-threshold error "$WORKSPACE/$ctx/Dockerfile"
          done
        '''
      } }
    }

    stage('4. Build & Push (Kaniko)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps { container('kaniko') { script {
        sh '''
          set -e
          mkdir -p "$WORKSPACE/digest" "$WORKSPACE/sbom" "$WORKSPACE/scan" "$WORKSPACE/reports"
          TAG="v0.10.6-${GIT_SHA}-b${BUILD_NUMBER}"
          for svc in $(echo "${BUILD_TARGET:-frontend}" | tr ',' ' '); do
            ctx="src/$svc"; [ "$svc" = "cartservice" ] && ctx="src/cartservice/src"
            echo "== building $svc from $ctx =="
            /kaniko/executor --context="dir://$WORKSPACE/$ctx" --dockerfile="$WORKSPACE/$ctx/Dockerfile" \
              --destination="$REGISTRY/$svc:$TAG" --digest-file="$WORKSPACE/digest/$svc.txt" \
              --cache=false --verbosity=warn
            echo "$svc -> $REGISTRY/$svc:$TAG @ $(cat $WORKSPACE/digest/$svc.txt)"
          done
        '''
      } } }
    }

    stage('5. SBOM (Syft)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps { container('tools') {
        sh '''
          set -e
          for f in digest/*.txt; do [ -f "$f" ] || continue
            svc=$(basename "$f" .txt)
            syft "$REGISTRY/$svc@$(cat $f)" -q \
              -o cyclonedx-json="$WORKSPACE/sbom/$svc.cdx.json" \
              -o spdx-json="$WORKSPACE/sbom/$svc.spdx.json"
            n=$(grep -o '"bom-ref"' "$WORKSPACE/sbom/$svc.cdx.json" | wc -l)
            echo "$svc SBOM components~=$n"
          done
        '''
      } }
    }

    stage('5b. Unit Tests (Go + .NET)') {
      steps {
        container('golang') {
          sh '''
            set -e
            for svc in frontend productcatalogservice shippingservice checkoutservice; do
              echo "== go test src/$svc =="
              (cd "$WORKSPACE/src/$svc" && go test ./...)
            done
          '''
        }
        container('dotnet') {
          sh '''
            echo "== dotnet test src/cartservice =="
            dotnet test "$WORKSPACE/src/cartservice/" --nologo
          '''
        }
      }
    }

    stage('6. Image Scan (Trivy, gate)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps { container('trivy') {
        sh '''
          set -e
          for f in digest/*.txt; do [ -f "$f" ] || continue
            svc=$(basename "$f" .txt); img="$REGISTRY/$svc@$(cat $f)"
            echo "== trivy scan $svc =="
            trivy image --insecure --scanners vuln --format json \
              -o "$WORKSPACE/scan/$svc.trivy.json" \
              --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 "$img" \
              || { echo "GATE FAILED: $svc has CRITICAL/HIGH fixable vulns"; exit 1; }
          done
        '''
      } }
    }

    stage('6b. SCA — source (Trivy fs)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps { container('trivy') {
        sh '''
          for svc in $(echo "${BUILD_TARGET:-frontend}" | tr ',' ' '); do
            echo "== trivy fs $svc =="
            trivy fs --scanners vuln --format json -o "$WORKSPACE/scan/$svc.fs.json" \
              --severity CRITICAL --ignore-unfixed --exit-code 1 "$WORKSPACE/src/$svc" \
              || { echo "SCA GATE FAILED (CRITICAL, fixable): $svc"; exit 1; }
          done
          echo "SCA: gated on CRITICAL; HIGH reported in scan/$svc.fs.json"
        '''
      } }
    }

    stage('6c. IaC & manifests (Trivy config)') {
      steps { container('trivy') {
        sh '''
          set -e
          for d in gitops kustomize/base; do
            name=$(basename "$d")
            trivy config --severity CRITICAL --exit-code 1 --format json \
              -o "$WORKSPACE/reports/iac-$name.json" "$WORKSPACE/$d" \
              || { echo "IaC GATE FAILED: $d (CRITICAL)"; exit 1; }
            test -s "$WORKSPACE/reports/iac-$name.json" || { echo "IaC report missing: $d"; exit 1; }
            echo "iac report written: iac-$name.json"
          done
        '''
      } }
    }

    stage('6d. License Scan (Trivy)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps { container('trivy') {
        sh '''
          for svc in $(echo "${BUILD_TARGET:-frontend}" | tr ',' ' '); do
            trivy fs --scanners license --format json -o "$WORKSPACE/reports/license-$svc.json" "$WORKSPACE/src/$svc" || true
          done
          echo "license reports: $(ls reports/license-*.json 2>/dev/null | wc -l)"
        '''
      } }
    }

    stage('7. SAST (Semgrep)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps { container('semgrep') {
        sh '''
          for svc in $(echo "${BUILD_TARGET:-frontend}" | tr ',' ' '); do
            semgrep --config p/default --severity ERROR --error --json -o "reports/semgrep-$svc.json" "src/$svc"
          done
          echo "semgrep reports: $(ls reports/semgrep-*.json 2>/dev/null | wc -l)"
        '''
      } }
    }

    stage('7b. Exception Expiry Gate') {
      steps { container('tools') {
        sh '''
          python3 -c "
import re, datetime, sys
s = open('security/exceptions.yaml').read()
exp = re.findall(r'expires:\\s*([0-9]{4}-[0-9]{2}-[0-9]{2})', s)
today = datetime.date.today()
bad = [e for e in exp if datetime.date.fromisoformat(e) < today]
print('exceptions:', len(exp), 'expired:', bad)
sys.exit(1 if bad else 0)
"
        '''
      } }
    }

    stage('8. Sign & Attest (cosign)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps { container('sign') {
        sh '''
          set -e
          SHA="${GIT_SHA:-manual}"
          FULL_SHA="$(git rev-parse HEAD)"
          START_TS="$(date -u +%FT%TZ)"
          for f in digest/*.txt; do [ -f "$f" ] || continue
            svc=$(basename "$f" .txt); img="$REGISTRY/$svc@$(cat $f)"
            cat > "$WORKSPACE/provenance-$svc.json" <<EOF
{
  "builder": {"id": "jenkins://boutique-app-ci"},
  "buildType": "https://jenkins.io/pipeline@v1",
  "invocation": {"configSource": {"uri": "https://github.com/Hephast0s/boutique-devsecops", "digest": {"sha1": "$FULL_SHA"}}, "parameters": {"service": "$svc"}},
  "metadata": {"buildInvocationId": "boutique-app-ci#${BUILD_NUMBER}", "buildStartedOn": "$START_TS", "completeness": {"parameters": true, "environment": false, "materials": false}, "reproducible": false}
}
EOF
            cosign sign --key /cosign/cosign.key --yes --allow-insecure-registry "$img"
            cosign attest --key /cosign/cosign.key --yes --allow-insecure-registry \
              --predicate "$WORKSPACE/sbom/$svc.cdx.json" --type cyclonedx "$img"
            cosign attest --key /cosign/cosign.key --yes --allow-insecure-registry \
              --predicate "$WORKSPACE/provenance-$svc.json" --type slsaprovenance "$img"
            echo "signed+attested $svc"
          done
        '''
      } }
    }

    stage('9. Verify (cosign)') {
      when { expression { return fileExists('digest') } }
      steps {
        container('sign') {
          sh '''
            set -e
            for f in digest/*.txt; do [ -f "$f" ] || continue
              svc=$(basename "$f" .txt); img="$REGISTRY/$svc@$(cat $f)"
              cosign verify --key "$WORKSPACE/security/cosign.pub" --allow-insecure-registry "$img" >/dev/null
              cosign verify-attestation --key "$WORKSPACE/security/cosign.pub" --type cyclonedx --allow-insecure-registry "$img" >/dev/null
              echo "verified $svc (signature + cyclonedx attestation)"
            done
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'sbom/*,scan/*,reports/*,digest/*,provenance-*.json', allowEmptyArchive: true
    }
  }
}
