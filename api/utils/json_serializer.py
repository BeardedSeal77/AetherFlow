# api/utils/json_serializer.py
"""
Custom JSON serializer to handle date/time objects from PostgreSQL.
"""

import json
import decimal
from datetime import date, datetime, time
from flask import Flask

class CustomJSONEncoder(json.JSONEncoder):
    """Custom JSON encoder that handles PostgreSQL date/time types"""
    
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        elif isinstance(obj, date):
            return obj.isoformat()
        elif isinstance(obj, time):
            return obj.strftime('%H:%M:%S')
        elif isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def configure_json_encoder(app: Flask):
    """Configure Flask app to use custom JSON encoder"""
    app.json_encoder = CustomJSONEncoder
    return app