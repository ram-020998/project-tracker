"""Test all Data Generator API endpoints against the Appian environment."""

import json
import requests

BASE_URL = "https://merge-assist.appianpreview.com"
API_KEY = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJmMWMwNTQ2Mi1lNjllLTIyNmItYzc3MS02ZGVjNDVhZDY3NzQifQ.2E_p7fxfO0girqHG0kkDwaLOTfbzsFvDXkH2lGHBSGs"  # Set your API key here

HEADERS = {
    "Appian-API-Key": API_KEY,
    "Content-Type": "application/json",
}

EVAL_UUID = "e6bc8561-d3a6-4679-b7af-6e279910468e"


def post(path, payload):
    url = f"{BASE_URL}{path}"
    print(f"\n{'='*60}")
    print(f"POST {url}")
    print(f"Body: {json.dumps(payload, indent=2)}")
    resp = requests.post(url, headers=HEADERS, json=payload, timeout=30)
    print(f"Status: {resp.status_code}")
    try:
        data = resp.json()
        print(f"Response: {json.dumps(data, indent=2)[:500]}")
    except:
        print(f"Response (raw): {resp.text[:500]}")
    return resp


def test_users():
    print("\n\n### TEST: list_users ###")
    post("/suite/webapi/users/list", {})


def test_properties():
    print("\n\n### TEST: get_record_properties ###")
    post("/suite/webapi/record/properties", {
        "recordType": EVAL_UUID,
    })


def test_query():
    print("\n\n### TEST: query_records ###")
    post("/suite/webapi/record/query", {
        "recordType": EVAL_UUID,
        "pagingInfo": {"startIndex": 1, "batchSize": 2},
    })


def test_create():
    print("\n\n### TEST: create_record ###")
    post("/suite/webapi/record/create", {
        "recordData": {
            "recordType": EVAL_UUID,
            "fields": {
                "evaluationTitle": "API Test Evaluation",
                "evaluationStatusId": 1,
                "isActive": True,
                "sourceApplicationId": 60,
            },
        },
    })


if __name__ == "__main__":
    if not API_KEY:
        print("ERROR: Set API_KEY in the script first")
        exit(1)

    test_users()
    test_properties()
    test_query()
    test_create()
