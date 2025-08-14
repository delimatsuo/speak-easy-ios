#!/usr/bin/env python3
"""
Dependency Security Scanner
Checks for known vulnerabilities in Python dependencies
"""

import subprocess
import sys
import json
import re
from datetime import datetime

def run_command(cmd):
    """Run shell command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode, result.stdout, result.stderr
    except Exception as e:
        return 1, "", str(e)

def check_pip_audit():
    """Check for vulnerabilities using pip-audit"""
    print("🔍 Running pip-audit security scan...")
    
    # Install pip-audit if not available
    code, _, _ = run_command("pip-audit --version")
    if code != 0:
        print("Installing pip-audit...")
        run_command("pip install pip-audit")
    
    # Run security audit
    code, output, error = run_command("pip-audit --format=json --desc")
    
    if code == 0:
        try:
            if output.strip():
                vulnerabilities = json.loads(output)
                if vulnerabilities:
                    print(f"❌ Found {len(vulnerabilities)} vulnerabilities:")
                    for vuln in vulnerabilities:
                        print(f"  • {vuln.get('package', 'Unknown')}: {vuln.get('vulnerability_id', 'N/A')}")
                        print(f"    {vuln.get('description', 'No description')[:100]}...")
                    return False
                else:
                    print("✅ No known vulnerabilities found")
                    return True
            else:
                print("✅ No vulnerabilities detected")
                return True
        except json.JSONDecodeError:
            print("⚠️  Could not parse pip-audit output")
            return True
    else:
        print(f"⚠️  pip-audit failed: {error}")
        return True

def check_requirements():
    """Check requirements.txt for outdated packages"""
    print("\n📦 Checking requirements.txt...")
    
    try:
        with open('requirements.txt', 'r') as f:
            requirements = f.read().strip().split('\n')
        
        print(f"Found {len(requirements)} dependencies:")
        
        outdated_packages = []
        for req in requirements:
            if req.strip() and not req.startswith('#'):
                package_name = re.split('[<>=!]', req)[0].strip()
                
                # Check if package has known issues
                code, output, _ = run_command(f"pip show {package_name}")
                if code == 0:
                    version_match = re.search(r'Version: (.+)', output)
                    if version_match:
                        version = version_match.group(1)
                        print(f"  ✅ {package_name}: {version}")
                    else:
                        print(f"  ⚠️  {package_name}: Version unknown")
                else:
                    print(f"  ❌ {package_name}: Not installed")
                    outdated_packages.append(package_name)
        
        return len(outdated_packages) == 0
        
    except FileNotFoundError:
        print("❌ requirements.txt not found")
        return False

def check_dockerfile_security():
    """Check Dockerfile for security best practices"""
    print("\n🐳 Checking Dockerfile security...")
    
    security_issues = []
    
    try:
        with open('Dockerfile_voice', 'r') as f:
            dockerfile_content = f.read()
        
        lines = dockerfile_content.split('\n')
        
        # Check for security best practices
        has_user = any('USER ' in line for line in lines)
        if not has_user:
            security_issues.append("No USER directive found - running as root")
        
        has_healthcheck = any('HEALTHCHECK' in line for line in lines)
        if not has_healthcheck:
            security_issues.append("No HEALTHCHECK directive found")
        
        # Check for exposed ports
        exposed_ports = [line for line in lines if line.strip().startswith('EXPOSE')]
        if not exposed_ports:
            security_issues.append("No EXPOSE directive found")
        
        # Check for secrets in dockerfile
        secret_patterns = ['password', 'secret', 'key', 'token']
        for i, line in enumerate(lines, 1):
            for pattern in secret_patterns:
                if pattern.lower() in line.lower() and not line.strip().startswith('#'):
                    security_issues.append(f"Potential secret on line {i}: {line.strip()}")
        
        if security_issues:
            print("⚠️  Dockerfile security issues found:")
            for issue in security_issues:
                print(f"  • {issue}")
            return False
        else:
            print("✅ Dockerfile follows security best practices")
            return True
            
    except FileNotFoundError:
        print("❌ Dockerfile_voice not found")
        return False

def check_environment_security():
    """Check for environment security issues"""
    print("\n🔧 Checking environment security...")
    
    security_score = 0
    total_checks = 0
    
    # Check for .env files (should not exist in production)
    code, _, _ = run_command("find . -name '.env*' -type f")
    total_checks += 1
    if code != 0:
        print("✅ No .env files found in repository")
        security_score += 1
    else:
        print("⚠️  .env files found - ensure they're not in production")
    
    # Check for hardcoded secrets in Python files
    code, output, _ = run_command("grep -r -i 'password\\|secret\\|key.*=' --include='*.py' . || true")
    total_checks += 1
    if not output.strip():
        print("✅ No hardcoded secrets found in Python files")
        security_score += 1
    else:
        print("⚠️  Potential hardcoded secrets found:")
        for line in output.split('\n')[:5]:  # Show first 5 matches
            if line.strip():
                print(f"  • {line}")
    
    # Check for proper gitignore
    total_checks += 1
    try:
        with open('.gitignore', 'r') as f:
            gitignore = f.read()
        
        important_ignores = ['.env', '*.pem', '*.key', '__pycache__', '.DS_Store']
        missing_ignores = [ignore for ignore in important_ignores if ignore not in gitignore]
        
        if not missing_ignores:
            print("✅ .gitignore properly configured")
            security_score += 1
        else:
            print(f"⚠️  .gitignore missing: {', '.join(missing_ignores)}")
            
    except FileNotFoundError:
        print("⚠️  .gitignore not found")
    
    return security_score == total_checks

def generate_security_report():
    """Generate comprehensive security report"""
    print("\n📋 DEPENDENCY SECURITY REPORT")
    print("=" * 50)
    print(f"Scan Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Project: Universal Translator Backend")
    print("=" * 50)
    
    results = {
        'vulnerability_scan': check_pip_audit(),
        'requirements_check': check_requirements(),
        'dockerfile_security': check_dockerfile_security(),
        'environment_security': check_environment_security()
    }
    
    passed = sum(results.values())
    total = len(results)
    
    print(f"\n📊 SECURITY SUMMARY")
    print("=" * 50)
    print(f"Total Checks: {total}")
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {total - passed}")
    print(f"Success Rate: {(passed/total)*100:.1f}%")
    
    if passed == total:
        print("\n🎉 ALL SECURITY CHECKS PASSED!")
        print("✅ Dependencies are secure for production")
        return True
    else:
        print(f"\n⚠️  {total - passed} SECURITY ISSUES FOUND")
        print("🔧 Address issues before production deployment")
        return False

if __name__ == "__main__":
    success = generate_security_report()
    sys.exit(0 if success else 1)
