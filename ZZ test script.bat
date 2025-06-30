# Test the simple workflow API endpoints

# 1. Test getting all accessories (for the general search)
echo "Testing all accessories endpoint..."
curl -X GET "http://localhost:5328/api/hire/accessories/all" | jq

echo -e "\n\n"

# 2. Test getting equipment accessories complete (the main workflow)
echo "Testing equipment accessories complete workflow..."
curl -X POST "http://localhost:5328/api/hire/equipment/accessories-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "equipment_selections": [
      {"equipment_type_id": 1, "quantity": 2}
    ]
  }' | jq

echo -e "\n\n"

# 3. Test with multiple equipment types
echo "Testing with multiple equipment types..."
curl -X POST "http://localhost:5328/api/hire/equipment/accessories-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "equipment_selections": [
      {"equipment_type_id": 1, "quantity": 2},
      {"equipment_type_id": 2, "quantity": 1}
    ]
  }' | jq

echo -e "\n\n"

# Expected results:
# 1. All accessories should return a list of all accessories in the system
# 2. Equipment accessories complete should return:
#    - Default accessories with calculated quantities (e.g., helmet=2, petrol=4L for 2 rammers)
#    - Optional accessories with quantity=0 (e.g., extra oil, gloves)
# 3. Multiple equipment should aggregate properly