"""Test related records write via MCP server."""

import asyncio
import os
import sys
import json

sys.path.insert(0, "/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp")

os.environ["APPIAN_ENV_URL"] = "https://merge-assist.appianpreview.com"
os.environ["APPIAN_API_KEY"] = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJmMWMwNTQ2Mi1lNjllLTIyNmItYzc3MS02ZGVjNDVhZDY3NzQifQ.2E_p7fxfO0girqHG0kkDwaLOTfbzsFvDXkH2lGHBSGs"  # Set your API key here

from data_generator.config import config
from data_generator.tools.record import RecordTools
from data_generator.tools.session import SessionTools

EVAL_UUID = "e6bc8561-d3a6-4679-b7af-6e279910468e"
VENDOR_UUID = "b6081510-0d11-4d51-8eba-966610b168db"
CRITERIA_UUID = "11dcc745-3c81-49f9-9cb2-6427680e4b41"


async def main():
    config.initialize()
    print(f"Connected to: {config.env_name}")

    # Create evaluation with related vendors and criteria
    print("\n--- CREATE WITH RELATED RECORDS ---")
    result = await RecordTools.create_record({
        "record_type_uuid": EVAL_UUID,
        "fields": {
            "evaluationTitle": "Related Records Test",
            "evaluationStatusId": 1,
            "isActive": True,
            "sourceApplicationId": 60,
        },
        "related_records": [
            {
                "relationshipName": "vendor",
                "recordType": VENDOR_UUID,
                "records": [
                    {"legalName": "Acme Federal LLC", "businessName": "Acme Federal", "isActive": True, "sourceApplicationId": 60},
                    {"legalName": "Beta Corp", "businessName": "Beta Corporation", "isActive": True, "sourceApplicationId": 60},
                ]
            },
            {
                "relationshipName": "criteria",
                "recordType": CRITERIA_UUID,
                "records": [
                    {"criteriaName": "Technical Approach", "factorNumber": "1", "isActive": True},
                ]
            }
        ]
    })
    print(result[0].text)

    # Check session
    print("\n--- SESSION ---")
    result = await SessionTools.get_session({})
    print(result[0].text)

    # Rollback
    print("\n--- ROLLBACK ---")
    result = await SessionTools.rollback_session({"confirm": True})
    print(result[0].text)


if __name__ == "__main__":
    if not os.environ.get("APPIAN_API_KEY"):
        print("ERROR: Set APPIAN_API_KEY in the script")
        exit(1)
    asyncio.run(main())
