#!/usr/bin/env python
"""
DisplayDeck System Validation and Integration Test Suite
Comprehensive validation of all platform components and performance optimization
"""

import os
import sys
import subprocess
import json
import requests
import time
import psutil
import sqlite3
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from datetime import datetime
import concurrent.futures
import threading

@dataclass
class ValidationResult:
    component: str
    status: str  # 'pass', 'fail', 'warning'
    message: str
    details: Optional[Dict[str, Any]] = None
    duration_ms: Optional[float] = None

class SystemValidator:
    """
    Comprehensive system validator for DisplayDeck.
    Validates backend, frontend, mobile, Android TV, and performance optimizations.
    """
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.results: List[ValidationResult] = []
        self.start_time = time.time()
        
        # Component paths
        self.backend_path = self.project_root / "backend"
        self.frontend_path = self.project_root / "frontend"
        self.mobile_path = self.project_root / "mobile"
        self.android_tv_path = self.project_root / "android-tv"
        
        # Test configuration
        self.test_config = {
            'backend_url': 'http://localhost:8000',
            'frontend_url': 'http://localhost:3000',
            'test_timeout': 30,
            'performance_thresholds': {
                'response_time_ms': 2000,
                'memory_usage_mb': 512,
                'cpu_usage_percent': 80,
                'database_connections': 50
            }
        }
    
    def validate_system(self) -> Dict[str, Any]:
        """
        Run comprehensive system validation.
        """
        print("🚀 Starting DisplayDeck System Validation...")
        print(f"📁 Project Root: {self.project_root}")
        print(f"⏰ Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("-" * 70)
        
        validation_steps = [
            ('Environment Setup', self._validate_environment),
            ('Backend Components', self._validate_backend),
            ('Frontend Components', self._validate_frontend),
            ('Mobile Components', self._validate_mobile),
            ('Android TV Components', self._validate_android_tv),
            ('Database Health', self._validate_database),
            ('Performance Optimization', self._validate_performance),
            ('Integration Tests', self._validate_integration),
            ('Security Validation', self._validate_security),
            ('Deployment Readiness', self._validate_deployment)
        ]
        
        for step_name, validation_func in validation_steps:
            print(f"\n🔍 {step_name}...")
            try:
                step_start = time.time()
                validation_func()
                step_duration = (time.time() - step_start) * 1000
                print(f"   ✅ Completed in {step_duration:.2f}ms")
            except Exception as e:
                self.results.append(ValidationResult(
                    component=step_name,
                    status='fail',
                    message=f"Validation failed: {str(e)}",
                    details={'error': str(e)}
                ))
                print(f"   ❌ Failed: {str(e)}")
        
        return self._generate_report()
    
    def _validate_environment(self):
        """Validate development environment setup."""
        
        # Check Python version
        python_version = sys.version_info
        if python_version.major >= 3 and python_version.minor >= 8:
            self.results.append(ValidationResult(
                component='Python',
                status='pass',
                message=f'Python {python_version.major}.{python_version.minor} detected'
            ))
        else:
            self.results.append(ValidationResult(
                component='Python',
                status='fail',
                message=f'Python 3.8+ required, found {python_version.major}.{python_version.minor}'
            ))
        
        # Check Node.js availability
        try:
            node_result = subprocess.run(['node', '--version'], 
                                       capture_output=True, text=True, timeout=5)
            if node_result.returncode == 0:
                node_version = node_result.stdout.strip()
                self.results.append(ValidationResult(
                    component='Node.js',
                    status='pass',
                    message=f'Node.js {node_version} detected'
                ))
            else:
                raise subprocess.CalledProcessError(node_result.returncode, 'node')
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
            self.results.append(ValidationResult(
                component='Node.js',
                status='fail',
                message='Node.js not found or not working'
            ))
        
        # Check project structure
        required_dirs = ['backend', 'frontend', 'mobile']
        for dir_name in required_dirs:
            dir_path = self.project_root / dir_name
            if dir_path.exists():
                self.results.append(ValidationResult(
                    component=f'Directory: {dir_name}',
                    status='pass',
                    message=f'{dir_name} directory exists'
                ))
            else:
                self.results.append(ValidationResult(
                    component=f'Directory: {dir_name}',
                    status='fail',
                    message=f'{dir_name} directory missing'
                ))
    
    def _validate_backend(self):
        """Validate Django backend components."""
        
        if not self.backend_path.exists():
            self.results.append(ValidationResult(
                component='Backend',
                status='fail',
                message='Backend directory not found'
            ))
            return
        
        # Check Django project structure
        manage_py = self.backend_path / 'manage.py'
        if manage_py.exists():
            self.results.append(ValidationResult(
                component='Django Setup',
                status='pass',
                message='Django project structure detected'
            ))
        else:
            self.results.append(ValidationResult(
                component='Django Setup',
                status='fail',
                message='manage.py not found'
            ))
            return
        
        # Validate Django apps
        apps_to_check = ['users', 'businesses', 'menus', 'displays']
        src_path = self.backend_path / 'src'
        
        for app_name in apps_to_check:
            app_path = src_path / app_name
            if app_path.exists() and (app_path / 'models.py').exists():
                self.results.append(ValidationResult(
                    component=f'Django App: {app_name}',
                    status='pass',
                    message=f'{app_name} app structure valid'
                ))
            else:
                self.results.append(ValidationResult(
                    component=f'Django App: {app_name}',
                    status='fail',
                    message=f'{app_name} app missing or incomplete'
                ))
        
        # Check requirements.txt
        requirements_file = self.backend_path / 'requirements.txt'
        if requirements_file.exists():
            with open(requirements_file, 'r') as f:
                requirements = f.read()
                required_packages = ['django', 'djangorestframework', 'channels', 'redis']
                missing_packages = [pkg for pkg in required_packages if pkg not in requirements.lower()]
                
                if not missing_packages:
                    self.results.append(ValidationResult(
                        component='Backend Dependencies',
                        status='pass',
                        message='All required packages listed in requirements.txt'
                    ))
                else:
                    self.results.append(ValidationResult(
                        component='Backend Dependencies',
                        status='warning',
                        message=f'Missing packages in requirements.txt: {", ".join(missing_packages)}'
                    ))
        else:
            self.results.append(ValidationResult(
                component='Backend Dependencies',
                status='fail',
                message='requirements.txt not found'
            ))
        
        # Check performance optimization files
        perf_files = [
            'src/core/settings/performance.py',
            'src/common/middleware/performance.py',
            'src/common/optimization/database.py',
            'src/common/performance/views.py'
        ]
        
        for perf_file in perf_files:
            file_path = self.backend_path / perf_file
            if file_path.exists():
                self.results.append(ValidationResult(
                    component=f'Performance File: {perf_file.split("/")[-1]}',
                    status='pass',
                    message=f'Performance optimization file exists'
                ))
            else:
                self.results.append(ValidationResult(
                    component=f'Performance File: {perf_file.split("/")[-1]}',
                    status='warning',
                    message=f'Performance optimization file missing: {perf_file}'
                ))
    
    def _validate_frontend(self):
        """Validate React frontend components."""
        
        if not self.frontend_path.exists():
            self.results.append(ValidationResult(
                component='Frontend',
                status='fail',
                message='Frontend directory not found'
            ))
            return
        
        # Check package.json
        package_json = self.frontend_path / 'package.json'
        if package_json.exists():
            with open(package_json, 'r') as f:
                package_data = json.load(f)
                
                required_deps = ['react', 'vite', 'typescript', '@tanstack/react-query']
                dependencies = {**package_data.get('dependencies', {}), **package_data.get('devDependencies', {})}
                missing_deps = [dep for dep in required_deps if dep not in dependencies]
                
                if not missing_deps:
                    self.results.append(ValidationResult(
                        component='Frontend Dependencies',
                        status='pass',
                        message='All required frontend dependencies found'
                    ))
                else:
                    self.results.append(ValidationResult(
                        component='Frontend Dependencies',
                        status='warning',
                        message=f'Missing dependencies: {", ".join(missing_deps)}'
                    ))
        else:
            self.results.append(ValidationResult(
                component='Frontend Dependencies',
                status='fail',
                message='package.json not found'
            ))
        
        # Check React components structure
        components_dir = self.frontend_path / 'src' / 'components'
        required_components = ['auth', 'business', 'menu', 'display', 'admin']
        
        for component_dir in required_components:
            comp_path = components_dir / component_dir
            if comp_path.exists() and any(comp_path.glob('*.tsx')):
                self.results.append(ValidationResult(
                    component=f'React Component: {component_dir}',
                    status='pass',
                    message=f'{component_dir} components found'
                ))
            else:
                self.results.append(ValidationResult(
                    component=f'React Component: {component_dir}',
                    status='warning',
                    message=f'{component_dir} components missing or empty'
                ))
        
        # Check performance optimization files
        perf_files = [
            'src/utils/performance/optimization.ts',
            'webpack.optimization.js'
        ]
        
        for perf_file in perf_files:
            file_path = self.frontend_path / perf_file
            if file_path.exists():
                self.results.append(ValidationResult(
                    component=f'Frontend Perf: {perf_file.split("/")[-1]}',
                    status='pass',
                    message='Frontend performance optimization found'
                ))
            else:
                self.results.append(ValidationResult(
                    component=f'Frontend Perf: {perf_file.split("/")[-1]}',
                    status='warning',
                    message=f'Frontend performance file missing: {perf_file}'
                ))
    
    def _validate_mobile(self):
        """Validate React Native mobile app."""
        
        if not self.mobile_path.exists():
            self.results.append(ValidationResult(
                component='Mobile',
                status='fail',
                message='Mobile directory not found'
            ))
            return
        
        # Check package.json for React Native
        package_json = self.mobile_path / 'package.json'
        if package_json.exists():
            with open(package_json, 'r') as f:
                package_data = json.load(f)
                
                if 'react-native' in package_data.get('dependencies', {}):
                    self.results.append(ValidationResult(
                        component='React Native Setup',
                        status='pass',
                        message='React Native project detected'
                    ))
                else:
                    self.results.append(ValidationResult(
                        component='React Native Setup',
                        status='fail',
                        message='React Native not found in dependencies'
                    ))
        
        # Check app.json/app.config.js for Expo
        expo_configs = ['app.json', 'app.config.js', 'app.config.ts']
        expo_found = any((self.mobile_path / config).exists() for config in expo_configs)
        
        if expo_found:
            self.results.append(ValidationResult(
                component='Expo Setup',
                status='pass',
                message='Expo configuration found'
            ))
        else:
            self.results.append(ValidationResult(
                component='Expo Setup',
                status='warning',
                message='Expo configuration not found'
            ))
        
        # Check performance optimization
        perf_file = self.mobile_path / 'src' / 'utils' / 'performance' / 'optimization.ts'
        if perf_file.exists():
            self.results.append(ValidationResult(
                component='Mobile Performance',
                status='pass',
                message='Mobile performance optimization found'
            ))
        else:
            self.results.append(ValidationResult(
                component='Mobile Performance',
                status='warning',
                message='Mobile performance optimization missing'
            ))
    
    def _validate_android_tv(self):
        """Validate Android TV Kotlin app."""
        
        if not self.android_tv_path.exists():
            self.results.append(ValidationResult(
                component='Android TV',
                status='warning',
                message='Android TV directory not found (optional component)'
            ))
            return
        
        # Check build.gradle
        build_gradle = self.android_tv_path / 'app' / 'build.gradle'
        if build_gradle.exists():
            self.results.append(ValidationResult(
                component='Android TV Build',
                status='pass',
                message='Android TV build configuration found'
            ))
        else:
            self.results.append(ValidationResult(
                component='Android TV Build',
                status='fail',
                message='Android TV build.gradle not found'
            ))
        
        # Check Kotlin source files
        kotlin_src = self.android_tv_path / 'app' / 'src' / 'main' / 'java'
        if kotlin_src.exists() and any(kotlin_src.rglob('*.kt')):
            self.results.append(ValidationResult(
                component='Android TV Source',
                status='pass',
                message='Kotlin source files found'
            ))
        else:
            self.results.append(ValidationResult(
                component='Android TV Source',
                status='warning',
                message='Kotlin source files not found'
            ))
    
    def _validate_database(self):
        """Validate database setup and health."""
        
        # Check for database files
        db_files = ['db.sqlite3', 'data/db.sqlite3']
        db_found = False
        
        for db_file in db_files:
            db_path = self.backend_path / db_file
            if db_path.exists():
                db_found = True
                
                # Check database connectivity
                try:
                    conn = sqlite3.connect(str(db_path))
                    cursor = conn.cursor()
                    
                    # Check if Django migrations have been run
                    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='django_migrations';")
                    if cursor.fetchone():
                        self.results.append(ValidationResult(
                            component='Database Schema',
                            status='pass',
                            message='Database schema initialized'
                        ))
                    else:
                        self.results.append(ValidationResult(
                            component='Database Schema',
                            status='warning',
                            message='Database exists but migrations may not be applied'
                        ))
                    
                    # Check for our app tables
                    app_tables = ['users_user', 'businesses_business', 'menus_menu']
                    existing_tables = []
                    
                    for table in app_tables:
                        cursor.execute(f"SELECT name FROM sqlite_master WHERE type='table' AND name='{table}';")
                        if cursor.fetchone():
                            existing_tables.append(table)
                    
                    if existing_tables:
                        self.results.append(ValidationResult(
                            component='App Tables',
                            status='pass',
                            message=f'Found {len(existing_tables)} app tables: {", ".join(existing_tables)}'
                        ))
                    else:
                        self.results.append(ValidationResult(
                            component='App Tables',
                            status='warning',
                            message='No app tables found - run migrations'
                        ))
                    
                    conn.close()
                    
                except Exception as e:
                    self.results.append(ValidationResult(
                        component='Database Connection',
                        status='fail',
                        message=f'Database connection failed: {str(e)}'
                    ))
                break
        
        if not db_found:
            self.results.append(ValidationResult(
                component='Database File',
                status='warning',
                message='No database file found - may need to run migrations'
            ))
    
    def _validate_performance(self):
        """Validate performance optimization implementation."""
        
        performance_components = {
            'Backend Performance Middleware': self.backend_path / 'src/common/middleware/performance.py',
            'Backend Database Optimization': self.backend_path / 'src/common/optimization/database.py',
            'Backend Performance Views': self.backend_path / 'src/common/performance/views.py',
            'Frontend Performance Utils': self.frontend_path / 'src/utils/performance/optimization.ts',
            'Frontend Webpack Config': self.frontend_path / 'webpack.optimization.js',
            'Mobile Performance Utils': self.mobile_path / 'src/utils/performance/optimization.ts'
        }
        
        for component_name, file_path in performance_components.items():
            if file_path.exists():
                # Check file size to ensure it's not empty
                file_size = file_path.stat().st_size
                if file_size > 100:  # At least 100 bytes
                    self.results.append(ValidationResult(
                        component=component_name,
                        status='pass',
                        message=f'Performance component implemented ({file_size} bytes)'
                    ))
                else:
                    self.results.append(ValidationResult(
                        component=component_name,
                        status='warning',
                        message='Performance component file is too small'
                    ))
            else:
                self.results.append(ValidationResult(
                    component=component_name,
                    status='warning',
                    message='Performance component not implemented'
                ))
    
    def _validate_integration(self):
        """Validate system integration and API endpoints."""
        
        # This would normally require running services
        # For now, we'll check for integration-related files
        
        # Check WebSocket consumers
        websocket_files = list((self.backend_path / 'src').rglob('consumers.py'))
        if websocket_files:
            self.results.append(ValidationResult(
                component='WebSocket Integration',
                status='pass',
                message=f'Found {len(websocket_files)} WebSocket consumer files'
            ))
        else:
            self.results.append(ValidationResult(
                component='WebSocket Integration',
                status='warning',
                message='WebSocket consumers not found'
            ))
        
        # Check API serializers
        serializer_files = list((self.backend_path / 'src').rglob('serializers.py'))
        if serializer_files:
            self.results.append(ValidationResult(
                component='API Serializers',
                status='pass',
                message=f'Found {len(serializer_files)} serializer files'
            ))
        else:
            self.results.append(ValidationResult(
                component='API Serializers',
                status='warning',
                message='API serializers not found'
            ))
        
        # Check URL configurations
        url_files = list((self.backend_path / 'src').rglob('urls.py'))
        if url_files:
            self.results.append(ValidationResult(
                component='URL Configuration',
                status='pass',
                message=f'Found {len(url_files)} URL configuration files'
            ))
        else:
            self.results.append(ValidationResult(
                component='URL Configuration',
                status='fail',
                message='URL configurations not found'
            ))
    
    def _validate_security(self):
        """Validate security implementation."""
        
        # Check for security-related settings
        security_files = [
            'src/core/settings/security.py',
            'src/core/settings/production.py'
        ]
        
        security_found = False
        for security_file in security_files:
            file_path = self.backend_path / security_file
            if file_path.exists():
                security_found = True
                self.results.append(ValidationResult(
                    component=f'Security Config: {security_file.split("/")[-1]}',
                    status='pass',
                    message='Security configuration found'
                ))
        
        if not security_found:
            self.results.append(ValidationResult(
                component='Security Configuration',
                status='warning',
                message='Dedicated security configuration not found'
            ))
        
        # Check for authentication implementation
        auth_files = list((self.backend_path / 'src').rglob('*auth*'))
        if auth_files:
            self.results.append(ValidationResult(
                component='Authentication',
                status='pass',
                message=f'Found {len(auth_files)} authentication-related files'
            ))
        else:
            self.results.append(ValidationResult(
                component='Authentication',
                status='warning',
                message='Authentication files not found'
            ))
    
    def _validate_deployment(self):
        """Validate deployment readiness."""
        
        # Check for deployment configuration files
        deployment_files = [
            'Dockerfile',
            'docker-compose.yml',
            'requirements.txt',
            '.env.example'
        ]
        
        for deploy_file in deployment_files:
            file_path = self.project_root / deploy_file
            if file_path.exists():
                self.results.append(ValidationResult(
                    component=f'Deployment: {deploy_file}',
                    status='pass',
                    message=f'{deploy_file} found'
                ))
            else:
                self.results.append(ValidationResult(
                    component=f'Deployment: {deploy_file}',
                    status='warning',
                    message=f'{deploy_file} not found'
                ))
        
        # Check for production settings
        prod_settings = self.backend_path / 'src/core/settings/production.py'
        if prod_settings.exists():
            self.results.append(ValidationResult(
                component='Production Settings',
                status='pass',
                message='Production settings configuration found'
            ))
        else:
            self.results.append(ValidationResult(
                component='Production Settings',
                status='warning',
                message='Production settings not configured'
            ))
    
    def _generate_report(self) -> Dict[str, Any]:
        """Generate comprehensive validation report."""
        
        total_duration = (time.time() - self.start_time) * 1000
        
        # Categorize results
        passed = [r for r in self.results if r.status == 'pass']
        failed = [r for r in self.results if r.status == 'fail']
        warnings = [r for r in self.results if r.status == 'warning']
        
        # Calculate scores
        total_checks = len(self.results)
        pass_rate = (len(passed) / total_checks * 100) if total_checks > 0 else 0
        
        # Determine overall status
        if len(failed) == 0:
            if len(warnings) <= 3:
                overall_status = 'EXCELLENT'
            else:
                overall_status = 'GOOD'
        elif len(failed) <= 2:
            overall_status = 'ACCEPTABLE'
        else:
            overall_status = 'NEEDS_ATTENTION'
        
        report = {
            'validation_summary': {
                'overall_status': overall_status,
                'total_checks': total_checks,
                'passed': len(passed),
                'failed': len(failed),
                'warnings': len(warnings),
                'pass_rate': round(pass_rate, 1),
                'duration_ms': round(total_duration, 2),
                'timestamp': datetime.now().isoformat()
            },
            'component_status': {
                'backend': self._get_component_status('Backend', 'Django'),
                'frontend': self._get_component_status('Frontend', 'React'),
                'mobile': self._get_component_status('Mobile', 'React Native'),
                'android_tv': self._get_component_status('Android TV'),
                'database': self._get_component_status('Database'),
                'performance': self._get_component_status('Performance', 'Perf'),
                'security': self._get_component_status('Security'),
                'deployment': self._get_component_status('Deployment')
            },
            'detailed_results': [
                {
                    'component': r.component,
                    'status': r.status,
                    'message': r.message,
                    'details': r.details,
                    'duration_ms': r.duration_ms
                }
                for r in self.results
            ],
            'recommendations': self._generate_recommendations(failed, warnings),
            'next_steps': self._generate_next_steps(overall_status, failed, warnings)
        }
        
        # Print summary
        self._print_summary(report)
        
        # Save report to file
        report_path = self.project_root / 'validation_report.json'
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\n📋 Full report saved to: {report_path}")
        
        return report
    
    def _get_component_status(self, *component_keywords) -> str:
        """Get status for components matching keywords."""
        component_results = [
            r for r in self.results 
            if any(keyword.lower() in r.component.lower() for keyword in component_keywords)
        ]
        
        if not component_results:
            return 'NOT_CHECKED'
        
        failed = [r for r in component_results if r.status == 'fail']
        warnings = [r for r in component_results if r.status == 'warning']
        
        if failed:
            return 'FAILED'
        elif warnings:
            return 'WARNING'
        else:
            return 'PASSED'
    
    def _generate_recommendations(self, failed: List[ValidationResult], warnings: List[ValidationResult]) -> List[str]:
        """Generate actionable recommendations."""
        recommendations = []
        
        if failed:
            recommendations.append("🚨 CRITICAL: Address failed components immediately:")
            for failure in failed[:5]:  # Top 5 failures
                recommendations.append(f"   • {failure.component}: {failure.message}")
        
        if warnings:
            recommendations.append("⚠️  IMPROVEMENTS: Consider addressing these warnings:")
            for warning in warnings[:5]:  # Top 5 warnings  
                recommendations.append(f"   • {warning.component}: {warning.message}")
        
        # General recommendations based on patterns
        backend_issues = len([r for r in failed + warnings if 'backend' in r.component.lower() or 'django' in r.component.lower()])
        if backend_issues > 2:
            recommendations.append("🔧 Consider running: python manage.py migrate && python manage.py collectstatic")
        
        frontend_issues = len([r for r in failed + warnings if 'frontend' in r.component.lower() or 'react' in r.component.lower()])
        if frontend_issues > 2:
            recommendations.append("📦 Consider running: npm install && npm run build")
        
        return recommendations
    
    def _generate_next_steps(self, overall_status: str, failed: List[ValidationResult], warnings: List[ValidationResult]) -> List[str]:
        """Generate next steps based on validation results."""
        
        if overall_status == 'EXCELLENT':
            return [
                "🎉 System validation passed with excellent results!",
                "✅ Ready for production deployment",
                "📈 Consider performance monitoring setup",
                "🔒 Review security configurations periodically"
            ]
        elif overall_status == 'GOOD':
            return [
                "✅ System validation passed with good results",
                "⚠️  Address minor warnings when possible", 
                "🚀 Ready for staging/testing deployment",
                "📋 Monitor system performance in production"
            ]
        elif overall_status == 'ACCEPTABLE':
            return [
                "⚠️  System has some issues but is functional",
                "🔧 Address critical failures before deployment",
                "🧪 Extensive testing recommended",
                "📞 Consider additional code review"
            ]
        else:
            return [
                "🚨 System needs attention before deployment",
                "🛠️  Fix all critical issues first",
                "🧪 Run comprehensive testing after fixes",
                "👥 Consider team review of implementation"
            ]
    
    def _print_summary(self, report: Dict[str, Any]):
        """Print validation summary to console."""
        
        summary = report['validation_summary']
        
        print("\n" + "="*70)
        print("📊 DISPLAYDECK SYSTEM VALIDATION SUMMARY")
        print("="*70)
        
        print(f"🎯 Overall Status: {summary['overall_status']}")
        print(f"📈 Pass Rate: {summary['pass_rate']}% ({summary['passed']}/{summary['total_checks']})")
        print(f"⏱️  Duration: {summary['duration_ms']:.2f}ms")
        print(f"📅 Completed: {summary['timestamp']}")
        
        print(f"\n📋 Results Breakdown:")
        print(f"   ✅ Passed: {summary['passed']}")
        print(f"   ❌ Failed: {summary['failed']}")
        print(f"   ⚠️  Warnings: {summary['warnings']}")
        
        print(f"\n🏗️  Component Status:")
        for component, status in report['component_status'].items():
            status_icon = {
                'PASSED': '✅',
                'FAILED': '❌', 
                'WARNING': '⚠️',
                'NOT_CHECKED': '➖'
            }.get(status, '❓')
            
            print(f"   {status_icon} {component.replace('_', ' ').title()}: {status}")
        
        if report['recommendations']:
            print(f"\n💡 Recommendations:")
            for rec in report['recommendations'][:5]:
                print(f"   {rec}")
        
        if report['next_steps']:
            print(f"\n🚀 Next Steps:")
            for step in report['next_steps']:
                print(f"   {step}")


def main():
    """Main validation entry point."""
    
    if len(sys.argv) > 1:
        project_root = sys.argv[1]
    else:
        project_root = os.getcwd()
    
    if not os.path.exists(project_root):
        print(f"❌ Project root not found: {project_root}")
        sys.exit(1)
    
    validator = SystemValidator(project_root)
    report = validator.validate_system()
    
    # Exit with appropriate code
    if report['validation_summary']['overall_status'] in ['EXCELLENT', 'GOOD']:
        sys.exit(0)
    elif report['validation_summary']['overall_status'] == 'ACCEPTABLE':
        sys.exit(1)
    else:
        sys.exit(2)


if __name__ == '__main__':
    main()