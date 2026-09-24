from datetime import datetime, timedelta, timezone
from github import Github
import duckdb
import os
from dotenv import load_dotenv
import pandas as pd
import requests


# Load environment variables from the local .env file
load_dotenv()

def update_github_secret(new_refresh_token):
  # Only run this if we are inside GitHub Actions
  if not os.getenv("GITHUB_ACTIONS"):
    print("Local run detected: Skipping automatic GitHub Secret update.")
    return

  try:
    # Authenticate using your GitHub PAT
    g = Github(os.getenv("GH_PAT"))
    repo = g.get_repo(os.getenv("GITHUB_REPOSITORY"))

    repo.create_secret("REFRESH_TOKEN", new_refresh_token)
    print("Successfully updated GitHub Secret with the new refresh token.")
  except Exception as e:
    print(f"Failed to update GitHub secret: {e}")

def refresh_access_token():
  url = "https://bandcamp.com/oauth_token"
  payload = {
      "grant_type": "refresh_token",
      "client_id": os.getenv("CLIENT_ID"),
      "client_secret": os.getenv("CLIENT_SECRET"),
      "refresh_token": os.getenv("REFRESH_TOKEN"),
  }
  try:
    response = requests.post(url, data=payload)
    response.raise_for_status()
    token_data = response.json()

    access_token = token_data.get("access_token")
    new_refresh_token = token_data.get("refresh_token")

    # If Bandcamp gave us a new refresh token, update GitHub secrets
    if new_refresh_token:
      update_github_secret(new_refresh_token)

    return access_token
  except requests.exceptions.RequestException as e:
    print(f"Failed to refresh token: {e}")
    return None


def get_band_id(access_token):
  url = "https://bandcamp.com/api/account/1/my_bands"
  if not access_token:
    return None

  headers = {"Authorization": f"Bearer {access_token}"}
  try:
    response = requests.post(url, headers=headers)
    response.raise_for_status()
    bands_data = response.json()
    return bands_data["bands"][0]["band_id"]
  except requests.exceptions.RequestException as e:
    print(f"Error fetching band ID: {e}")
    return None


def get_sales_report(access_token, band_id):
  url = "https://bandcamp.com/api/sales/4/sales_report"
  if not access_token or not band_id:
    print("Missing access token or band ID.")
    return None

  # Daily run: get sales from the last 25 hours to ensure a 1-hour overlap buffer
  end_time = datetime.now(timezone.utc)
  start_time = end_time - timedelta(hours=25)

  payload = {
      "band_id": band_id,
      "start_time": start_time.strftime("%Y-%m-%d %H:%M:%S"),
      "end_time": end_time.strftime("%Y-%m-%d %H:%M:%S"),
  }

  headers = {"Authorization": f"Bearer {access_token}"}
  try:
    response = requests.post(url, json=payload, headers=headers)
    response.raise_for_status()
    return response.json()
  except requests.exceptions.RequestException as e:
    print(f"Error fetching sales report: {e}")
    if e.response is not None:
      print(f"Response body: {e.response.text}")
    return None


def save_to_duckdb(sales_report):
  if not sales_report:
    print("No sales report data received to save.")
    return

  con = duckdb.connect("md:my_db")

  sales_items = sales_report.get("report", [])

  if not sales_items:
    print(
        "No individual sales records found in the report for this time window."
    )
    con.close()
    return

  df = pd.DataFrame(sales_items)

  # Create table if it doesn't exist, then append the new rows
  con.execute("CREATE TABLE IF NOT EXISTS bandcamp_raw_sales AS SELECT * FROM df WHERE 1=0")
  con.append("bandcamp_raw_sales", df)

  print(
      f"Successfully ingested {len(df)} sales records into DuckDB table 'bandcamp_raw_sales'."
  )

  # Quick verification query
  result = con.execute("SELECT COUNT(*) FROM bandcamp_raw_sales").fetchone()
  print(f"Total rows in DuckDB now: {result[0]}")

  con.close()


if __name__ == "__main__":
  token = refresh_access_token()
  if token:
    b_id = get_band_id(token)
    if b_id:
      report = get_sales_report(token, b_id)
      save_to_duckdb(report)