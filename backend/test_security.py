#!/usr/bin/env python3
"""
Security functionality testing script
"""

import asyncio
import aiohttp
import time
import json
from typing import List, Dict

API_BASE_URL = "https://universal-translator-api-jzqoowo3tq-uc.a.run.app"

async def test_rate_limiting():
    """Test rate limiting functionality"""
    print("🔄 Testing Rate Limiting")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    # Test translation endpoint rate limiting (60 requests per minute)
    async with aiohttp.ClientSession() as session:
        start_time = time.time()
        tasks = []
        
        # Send 65 requests quickly to trigger rate limiting
        for i in range(65):
            task = make_translation_request(session, i)
            tasks.append(task)
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        success_count = 0
        rate_limited_count = 0
        error_count = 0
        
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                error_count += 1
                print(f"  Request {i+1}: ERROR - {result}")
            elif result.get('status') == 429:
                rate_limited_count += 1
                print(f"  Request {i+1}: RATE LIMITED ✅")
            elif result.get('status') == 200:
                success_count += 1
                print(f"  Request {i+1}: SUCCESS")
            else:
                error_count += 1
                print(f"  Request {i+1}: UNEXPECTED - {result}")
        
        end_time = time.time()
        
        print(f"\n📊 Rate Limiting Test Results:")
        print(f"  • Total requests: 65")
        print(f"  • Successful: {success_count}")
        print(f"  • Rate limited: {rate_limited_count}")
        print(f"  • Errors: {error_count}")
        print(f"  • Duration: {end_time - start_time:.2f}s")
        
        if rate_limited_count > 0:
            print("  ✅ Rate limiting is working!")
        else:
            print("  ❌ Rate limiting may not be working properly")

async def make_translation_request(session: aiohttp.ClientSession, request_id: int) -> Dict:
    """Make a single translation request"""
    try:
        async with session.post(
            f"{API_BASE_URL}/v1/translate",
            json={
                "text": f"Test message {request_id}",
                "source_language": "en",
                "target_language": "es"
            },
            timeout=aiohttp.ClientTimeout(total=10)
        ) as response:
            return {
                "status": response.status,
                "request_id": request_id,
                "data": await response.json() if response.status == 200 else await response.text()
            }
    except Exception as e:
        return {"status": "error", "request_id": request_id, "error": str(e)}

async def test_health_endpoint():
    """Test health endpoint"""
    print("\n🏥 Testing Health Endpoint")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(f"{API_BASE_URL}/health") as response:
                data = await response.json()
                print(f"  Status: {response.status}")
                print(f"  Service Status: {data.get('status')}")
                print(f"  Version: {data.get('version')}")
                print(f"  Environment: {data.get('environment')}")
                print(f"  Uptime: {data.get('uptime_seconds', 0):.2f}s")
                
                if response.status == 200:
                    print("  ✅ Health endpoint working")
                else:
                    print("  ❌ Health endpoint issues")
                    
        except Exception as e:
            print(f"  ❌ Health endpoint error: {e}")

async def test_translation_endpoint():
    """Test basic translation functionality"""
    print("\n🌐 Testing Translation Endpoint")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    test_cases = [
        {"text": "Hello world", "source": "en", "target": "es"},
        {"text": "Good morning", "source": "en", "target": "fr"},
        {"text": "How are you?", "source": "en", "target": "de"},
    ]
    
    async with aiohttp.ClientSession() as session:
        for i, test_case in enumerate(test_cases, 1):
            try:
                start_time = time.time()
                async with session.post(
                    f"{API_BASE_URL}/v1/translate",
                    json={
                        "text": test_case["text"],
                        "source_language": test_case["source"],
                        "target_language": test_case["target"]
                    },
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    end_time = time.time()
                    
                    if response.status == 200:
                        data = await response.json()
                        print(f"  Test {i}: ✅ SUCCESS")
                        print(f"    Original: {test_case['text']}")
                        print(f"    Translated: {data.get('translated_text')}")
                        print(f"    Confidence: {data.get('confidence', 0):.2f}")
                        print(f"    Response time: {end_time - start_time:.2f}s")
                    else:
                        error_text = await response.text()
                        print(f"  Test {i}: ❌ FAILED (Status: {response.status})")
                        print(f"    Error: {error_text}")
                        
            except Exception as e:
                print(f"  Test {i}: ❌ ERROR - {e}")

async def test_security_headers():
    """Test security headers and HTTPS"""
    print("\n🔒 Testing Security Headers")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(f"{API_BASE_URL}/health") as response:
                headers = response.headers
                
                print(f"  HTTPS: {'✅' if response.url.scheme == 'https' else '❌'}")
                print(f"  Content-Type: {headers.get('content-type', 'Not set')}")
                print(f"  Server: {headers.get('server', 'Not disclosed')}")
                
                # Check for security headers
                security_headers = [
                    'X-Content-Type-Options',
                    'X-Frame-Options',
                    'X-XSS-Protection',
                    'Strict-Transport-Security'
                ]
                
                for header in security_headers:
                    value = headers.get(header.lower(), 'Not set')
                    status = '✅' if value != 'Not set' else '⚠️'
                    print(f"  {header}: {status} {value}")
                    
        except Exception as e:
            print(f"  ❌ Security headers test error: {e}")

async def main():
    """Run all security tests"""
    print("🔐 Security Testing Suite")
    print("=" * 50)
    
    await test_health_endpoint()
    await test_translation_endpoint()
    await test_rate_limiting()
    await test_security_headers()
    
    print("\n🎯 Security Testing Complete!")
    print("=" * 50)

if __name__ == "__main__":
    asyncio.run(main())
