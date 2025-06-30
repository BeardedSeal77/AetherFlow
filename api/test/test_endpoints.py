# test_endpoints.py - Run this to test your new API endpoints
import requests
import json

BASE_URL = "http://localhost:5328/api/hire"

def test_endpoint(url, method='GET', data=None, description=""):
    """Test an API endpoint and print results"""
    print(f"\n{'='*60}")
    print(f"Testing: {description}")
    print(f"URL: {url}")
    print(f"Method: {method}")
    
    try:
        if method == 'GET':
            response = requests.get(url)
        elif method == 'POST':
            response = requests.post(url, json=data, headers={'Content-Type': 'application/json'})
        
        print(f"Status Code: {response.status_code}")
        
        if response.headers.get('content-type') == 'application/json':
            result = response.json()
            print(f"Success: {result.get('success', 'N/A')}")
            
            if result.get('success'):
                data_count = 0
                if isinstance(result.get('data'), list):
                    data_count = len(result['data'])
                elif isinstance(result.get('data'), dict):
                    data_count = len(result['data'])
                
                print(f"Data Count: {data_count}")
                print(f"Sample Data: {json.dumps(result.get('data', {})[:1] if isinstance(result.get('data'), list) else result.get('data', {}), indent=2)[:200]}...")
            else:
                print(f"Error: {result.get('error', 'Unknown error')}")
        else:
            print(f"Response: {response.text[:200]}...")
            
    except Exception as e:
        print(f"Request failed: {str(e)}")

def main():
    """Test all the new endpoints"""
    print("Testing Equipment & Accessories API Endpoints")
    print("=" * 60)
    
    # Test basic health check
    test_endpoint(f"{BASE_URL}/test", description="Health Check")
    
    # Test equipment types
    test_endpoint(f"{BASE_URL}/equipment/types", description="Get Equipment Types")
    
    # Test all accessories
    test_endpoint(f"{BASE_URL}/accessories/all", description="Get All Accessories")
    
    # Test equipment accessories 
    equipment_data = {
        "equipment_type_ids": [1, 2]
    }
    test_endpoint(f"{BASE_URL}/equipment/accessories", method="POST", data=equipment_data, 
                 description="Get Equipment Accessories")
    
    # Test auto-accessories calculation
    auto_accessories_data = {
        "equipment_selections": [
            {"equipment_type_id": 1, "quantity": 2},
            {"equipment_type_id": 2, "quantity": 1}
        ]
    }
    test_endpoint(f"{BASE_URL}/equipment/auto-accessories", method="POST", data=auto_accessories_data,
                 description="Calculate Auto Accessories")
    
    # Test comprehensive equipment data with defaults
    comprehensive_data = {
        "equipment_selections": [
            {"equipment_type_id": 1, "quantity": 2}
        ]
    }
    test_endpoint(f"{BASE_URL}/equipment/accessories-with-defaults", method="POST", data=comprehensive_data,
                 description="Get Equipment Accessories with Defaults")
    
    # Test accessory validation
    validation_data = {
        "accessory_selections": [
            {"accessory_id": 1, "quantity": 2.0, "accessory_type": "default"},
            {"accessory_id": 2, "quantity": 0, "accessory_type": "optional"},
            {"accessory_id": 3, "quantity": -1, "accessory_type": "standalone"}  # This should fail validation
        ]
    }
    test_endpoint(f"{BASE_URL}/accessories/validate", method="POST", data=validation_data,
                 description="Validate Accessory Selection")
    
    # Test comprehensive endpoint
    comprehensive_test_data = {
        "equipment_selections": [
            {"equipment_type_id": 1, "quantity": 2}
        ],
        "search_term": "rammer",
        "delivery_date": "2025-07-01",
        "include_all_accessories": True
    }
    test_endpoint(f"{BASE_URL}/equipment/comprehensive-data", method="POST", data=comprehensive_test_data,
                 description="Get Comprehensive Equipment Data")
    
    # Test accessories test endpoint (if available)
    test_endpoint(f"{BASE_URL}/test/accessories", description="Test Accessories Functionality")
    
    print(f"\n{'='*60}")
    print("Testing Complete!")
    print("If any endpoints failed, check:")
    print("1. Flask server is running on localhost:5328")
    print("2. Database is connected and procedures are installed")
    print("3. Service container is properly initialized")
    print("4. No import errors in the service files")

if __name__ == "__main__":
    main()