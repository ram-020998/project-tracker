"""End-to-end test of the MCP server tools against the live Appian environment."""

import asyncio
import os
import sys

sys.path.insert(0, "/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp")

os.environ["APPIAN_ENV_URL"] = "https://merge-assist.appianpreview.com"
os.environ["APPIAN_API_KEY"] = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJmMWMwNTQ2Mi1lNjllLTIyNmItYzc3MS02ZGVjNDVhZDY3NzQifQ.2E_p7fxfO0girqHG0kkDwaLOTfbzsFvDXkH2lGHBSGs"  # Set your API key here

from data_generator.config import config
from data_generator.tools.properties import PropertiesTools
from data_generator.tools.record import RecordTools
from data_generator.tools.users import UsersTools
from data_generator.tools.session import SessionTools

EVAL_UUID = "e6bc8561-d3a6-4679-b7af-6e279910468e"


async def main():
    config.initialize()
    print(f"Connected to: {config.env_name}")

    # 1. List users
    print("\n--- LIST USERS ---")
    result = await UsersTools.list_users({})
    print(result[0].text[:300])

    # 2. Get record properties
    print("\n--- GET RECORD PROPERTIES ---")
    result = await PropertiesTools.get_record_properties({"record_type_uuid": EVAL_UUID})
    print(result[0].text[:500])

    # 3. Create a record
    print("\n--- CREATE RECORD ---")
    result = await RecordTools.create_record({
        "record_type_uuid": EVAL_UUID,
        "fields": {
            "evaluationTitle": "MCP Server Test Record",
            "evaluationStatusId": 1,
            "isActive": True,
            "sourceApplicationId": 60,
        },
    })
    print(result[0].text[:500])

    # Extract created ID
    import json
    create_response = json.loads(result[0].text)
    if not create_response.get("success"):
        print("CREATE FAILED - stopping")
        return

    # Try to get the record ID from response
    records_updated = create_response.get("recordsUpdated")
    print(f"\nrecordsUpdated: {records_updated}")

    # 4. Query to verify
    print("\n--- QUERY RECORD ---")
    result = await RecordTools.query_records({
        "record_type_uuid": EVAL_UUID,
        "filters": [{"field": "evaluationTitle", "operator": "=", "value": "MCP Server Test Record"}],
        "selected_fields": ["evaluationId", "evaluationTitle", "evaluationStatusId", "isActive"],
        "paging_info": {"startIndex": 1, "batchSize": 5},
    })
    print(result[0].text[:500])

    # 5. Get session
    print("\n--- GET SESSION ---")
    result = await SessionTools.get_session({})
    print(result[0].text[:300])

    # 6. Rollback
    print("\n--- ROLLBACK SESSION ---")
    result = await SessionTools.rollback_session({"confirm": True})
    print(result[0].text[:500])

    print("\n--- DONE ---")


if __name__ == "__main__":
    if not os.environ.get("APPIAN_API_KEY"):
        print("ERROR: Set APPIAN_API_KEY in the script")
        exit(1)
    asyncio.run(main())
