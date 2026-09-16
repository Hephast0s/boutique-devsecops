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
      image: python:3.14-alpine
      command: ['sleep']
      args: ['3600']
      env:
        - name: COSIGN_PASSWORD
          valueFrom: {secretKeyRef: {name: cosign-key, key: COSIGN_PASSWORD}}
      volumeMounts:
        - {name: cosign-key, mountPath: /cosign, readOnly: true}
      resources: {requests: {cpu: "50m", memory: "128Mi"}, limits: {cpu: "1000m", memory: "1Gi"}}
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
      image: aquasec/trivy:latest
      command: ['sleep']
      args: ['3600']
      resources: {requests: {cpu: "50m", memory: "128Mi"}, limits: {cpu: "500m", memory: "1Gi"}}
    - name: semgrep
      image: semgrep/semgrep:latest
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
    string(name: 'SERVICE', defaultValue: 'frontend', description: 'Service(s) to build, comma-separated (from ci/services.yaml)')
    booleanParam(name: 'FORCE_ALL', defaultValue: false, description: 'Build every service')
  }

  environment {
    REGISTRY = '192.168.1.8:30082/boutique'
  }

  options { buildDiscarder(logRotator(numToKeepStr: '10')); timeout(time: 45, unit: 'MINUTES') }

  stages {
    stage('1. Preflight') {
      steps { container('tools') { script {
        sh 'apk add --no-cache git bash syft cosign >/dev/null 2>&1 || true; git config --global --add safe.directory "*" || true'
        env.GIT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        echo "git_sha=${env.GIT_SHA}"
      } } }
    }

    stage('2. Change Detection') {
      steps { container('tools') { script {
        def changed = sh(script: 'bash ci/scripts/detect-changes.sh origin/devsecops || true', returnStdout: true).trim()
        env.CHANGED_SERVICES = changed.replace('\n', ',')
        env.BUILD_TARGET = params.FORCE_ALL ? 'ALL' : (params.SERVICE ?: env.CHANGED_SERVICES)
        echo "changed=${env.CHANGED_SERVICES ?: '(none)'} target=${env.BUILD_TARGET}"
      } } }
    }

    stage('3. Secret Scan (gitleaks)') {
      steps { container('gitleaks') {
        sh 'gitleaks dir . --config .gitleaks.toml --redact --no-banner --exit-code 1'
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

    stage('7. SAST (Semgrep)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps { container('semgrep') {
        sh '''
          for svc in $(echo "${BUILD_TARGET:-frontend}" | tr ',' ' '); do
            semgrep --config p/default --json -o "reports/semgrep-$svc.json" "src/$svc" 2>/dev/null || true
          done
          echo "semgrep reports: $(ls reports/semgrep-*.json 2>/dev/null | wc -l)"
        '''
      } }
    }

    stage('8. Sign & Attest (cosign)') {
      when { expression { return env.BUILD_TARGET != '' } }
      steps { container('tools') {
        sh '''
          set -e
          SHA="${GIT_SHA:-manual}"
          for f in digest/*.txt; do [ -f "$f" ] || continue
            svc=$(basename "$f" .txt); img="$REGISTRY/$svc@$(cat $f)"
            cat > "$WORKSPACE/provenance-$svc.json" <<EOF
{
  "builder": {"id": "jenkins://boutique-app-ci"},
  "buildType": "https://jenkins.io/pipeline@v1",
  "invocation": {"configSource": {"uri": "https://github.com/Hephast0s/boutique-devsecops", "digest": {"sha1": "$SHA"}}, "parameters": {"service": "$svc"}},
  "metadata": {"buildInvocationId": "boutique-app-ci#${BUILD_NUMBER}", "buildStartedOn": "2026-09-16T00:00:00Z", "completeness": {"parameters": true, "environment": false, "materials": false}, "reproducible": false}
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
        container('tools') {
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
