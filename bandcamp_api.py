from datetime import datetime, timedelta, timezone
from github import Auth, Github
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
        auth = Auth.Token(os.getenv("GH_PAT"))
        g = Github(auth=auth)
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

def get_sales_report(access_token, band_id, start_time=None, end_time=None):
    url = "https://bandcamp.com/api/sales/4/sales_report"
    if not access_token or not band_id:
        print("Missing access token or band ID.")
        return None

    # Fallback to the last 25 hours if no specific window is provided
    if not end_time:
        end_time = datetime.now(timezone.utc)
    if not start_time:
        start_time = end_time - timedelta(hours=25)

    # Ensure formatting strings are handled cleanly whether datetimes or strings are passed
    start_str = start_time.strftime("%Y-%m-%d %H:%M:%S") if isinstance(start_time, datetime) else start_time
    end_str = end_time.strftime("%Y-%m-%d %H:%M:%S") if isinstance(end_time, datetime) else end_time

    payload = {
        "band_id": band_id,
        "start_time": start_str,
        "end_time": end_str,
    }

    headers = {"Authorization": f"Bearer {access_token}"}
    try:
        response = requests.post(url, json=payload, headers=headers)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching sales report for window {start_str} to {end_str}: {e}")
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
        print("No individual sales records found in the report for this time window.")
        con.close()
        return

    df = pd.DataFrame(sales_items)

    # Convert *everything* to string first to prevent type inference collisions 
    # (IDs, notes, dates, codes won't cause unexpected integer/float casting crashes)
    for col in df.columns:
        df[col] = df[col].astype(str)

    con.register('df_view', df)
    
    con.execute("""
        CREATE TABLE IF NOT EXISTS bandcamp_raw_sales AS 
        SELECT * FROM df_view WHERE 1=0
    """)
    
    con.execute("""
        INSERT INTO bandcamp_raw_sales 
        SELECT * FROM df_view
    """)
    
    con.unregister('df_view')

    print(f"Successfully ingested {len(df)} sales records into DuckDB table 'bandcamp_raw_sales'.")

    result = con.execute("SELECT COUNT(*) FROM bandcamp_raw_sales").fetchone()
    print(f"Total rows in DuckDB now: {result[0]}")

    con.close()

def run_historical_backfill(access_token, band_id, start_year=2018):
  """Iterates through time in monthly chunks from start_year to today,

  fetching and ingesting historical Bandcamp sales data.
  """
  current_start = datetime(start_year, 1, 1, 0, 0, 0, tzinfo=timezone.utc)
  now = datetime.now(timezone.utc)
  chunk_size = timedelta(days=30)

  print(f"Starting historical backfill from {start_year}-01-01 to {now.strftime('%Y-%m-%d')}...")

  while current_start < now:
    chunk_end = min(current_start + chunk_size, now)

    print(f"Fetching chunk: {current_start.strftime('%Y-%m-%d')} to {chunk_end.strftime('%Y-%m-%d')}")

    # Fetch chunk and ingest directly
    report = get_sales_report(access_token, band_id, start_time=current_start, end_time=chunk_end)
    if report:
      save_to_duckdb(report)

    # Move forward to the next chunk
    current_start = chunk_end

  print("Historical backfill complete!")

if __name__ == "__main__":
  token = refresh_access_token()
  if token:
    b_id = get_band_id(token)
    if b_id:
      # To run your normal daily ingestion, use:
      # report = get_sales_report(token, b_id)
      # save_to_duckdb(report)

      # To run your massive backfill, uncomment below:
      run_historical_backfill(token, b_id, start_year=2018)