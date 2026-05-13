"""Check field names for vendor and criteria record types."""

import os
import sys
import json

sys.path.insert(0, "/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp")

os.environ["APPIAN_ENV_URL"] = "https://merge-assist.appianpreview.com"
os.environ["APPIAN_API_KEY"] = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJmMWMwNTQ2Mi1lNjllLTIyNmItYzc3MS02ZGVjNDVhZDY3NzQifQ.2E_p7fxfO0girqHG0kkDwaLOTfbzsFvDXkH2lGHBSGs"  # Set your API key here

from data_generator.config import config
from data_generator.client import AppianClient

VENDOR_UUID = "b6081510-0d11-4d51-8eba-966610b168db"
CRITERIA_UUID = "11dcc745-3c81-49f9-9cb2-6427680e4b41"

config.initialize()
client = AppianClient()

print("--- VENDOR FIELDS ---")
data = client.get_record_properties(VENDOR_UUID)
fields = data["recordType"]["fields"][0]
names = fields["name"]
types = fields["type"]
for n, t in zip(names, types):
    print(f"  {n}: {t}")

print("\n--- CRITERIA FIELDS ---")
data = client.get_record_properties(CRITERIA_UUID)
fields = data["recordType"]["fields"][0]
names = fields["name"]
types = fields["type"]
for n, t in zip(names, types):
    print(f"  {n}: {t}")
