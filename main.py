from fastapi import FastAPI, HTTPException, Request, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from database.database_connection import SessionLocal
from database.data_models import Order, Deal, Position, Account
from pydantic_models import OrderBase, DealBase, PositionBase, AccountBase
from typing import List, Dict, Any, Optional
import os
import json
import traceback
from datetime import datetime, timezone
import pytz
import uvicorn

app = FastAPI()

# Create a directory to store the files if it doesn't exist
os.makedirs("data", exist_ok=True)

def save_data_to_file(data:dict, filename:str):
    filename = f"data/{filename}.json"
    with open(filename, "w") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def convert_to_sg_time(timestamp: Optional[int], *, is_milliseconds=False) -> Optional[datetime]:
    """
    Convert epoch timestamp to Singapore time datetime object.
    
    Args:
        timestamp: Epoch timestamp in seconds or milliseconds (in Eastern European Time)
        is_milliseconds: Whether the timestamp is in milliseconds (True) or seconds (False)
        
    Returns:
        datetime object in Singapore timezone or None if timestamp is None
    """
    if timestamp is None:
        return None
    
    # Convert to seconds if in milliseconds
    seconds_timestamp = timestamp / 1000 if is_milliseconds else timestamp
    
    # Create a datetime object assuming the timestamp is in Eastern European Time (EET)
    # EET is UTC+2 in winter and UTC+3 in summer (with daylight saving)
    # Check if it's summer time (roughly April to October)
    month = datetime.fromtimestamp(seconds_timestamp).month
    is_summer = 4 <= month <= 10
    eet_offset = 3 if is_summer else 2  # Hours ahead of UTC
    
    # Adjust timestamp to get UTC time (subtract EET offset)
    utc_seconds = seconds_timestamp - (eet_offset * 3600)
    utc_dt = datetime.fromtimestamp(utc_seconds, timezone.utc)
    
    # Convert to Singapore timezone (UTC+8)
    sg_timezone = pytz.timezone('Asia/Singapore')
    sg_dt = utc_dt.astimezone(sg_timezone)

    return sg_dt

@app.post("/ping")
async def ping():
    print("Received ping from MT5")
    return {"status": "OK"}

@app.post("/order")
async def order_data(orders: List[OrderBase], db: Session = Depends(get_db)):
    try:
        # Save raw JSON data to a file as list of dicts, not double JSON string
        raw_data = [order.model_dump() for order in orders]
        save_data_to_file(raw_data, "orders")
            
        for item in orders:
            data_dict = item.model_dump()
            
            # Convert timestamps to Singapore time
            sg_time_data = {
                'time_setup_sg': convert_to_sg_time(data_dict.get('time_setup')),
                'time_expiration_sg': convert_to_sg_time(data_dict.get('time_expiration')),
                'time_done_sg': convert_to_sg_time(data_dict.get('time_done')),
                'time_setup_msc_sg': convert_to_sg_time(data_dict.get('time_setup_msc'), is_milliseconds=True),
                'time_done_msc_sg': convert_to_sg_time(data_dict.get('time_done_msc'), is_milliseconds=True)
            }
            
            # Add Singapore time fields to data
            data_dict.update(sg_time_data)
            
            existing = db.query(Order).filter(Order.ticket == item.ticket).first()
            if existing:
                for key, value in data_dict.items():
                    if hasattr(existing, key):
                        setattr(existing, key, value)
            else:
                order = Order(**data_dict)
                db.add(order)

        db.commit()
        return {"message": "Order data saved successfully"}
    except Exception as e:
        error_details = traceback.format_exc()
        print(f"Error in order_data: {str(e)}")
        print(f"Detailed traceback: {error_details}")
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/deal")
async def deal_data(deals: List[DealBase], db: Session = Depends(get_db)):
    try:
        raw_data = [deal.model_dump() for deal in deals]
        save_data_to_file(raw_data, "deals")
        
        for item in deals:
            data_dict = item.model_dump()
            
            # Convert timestamps to Singapore time
            sg_time_data = {
                'time_sg': convert_to_sg_time(data_dict.get('time')),
                'time_msc_sg': convert_to_sg_time(data_dict.get('time_msc'), is_milliseconds=True)
            }
            
            # Add Singapore time fields to data
            data_dict.update(sg_time_data)
            
            existing = db.query(Deal).filter(Deal.ticket == item.ticket).first()
            if existing:
                for key, value in data_dict.items():
                    if hasattr(existing, key):
                        setattr(existing, key, value)
            else:
                deal = Deal(**data_dict)
                db.add(deal)

        db.commit()
        return {"message": "Deal data saved successfully"}
    except Exception as e:
        error_details = traceback.format_exc()
        print(f"Error in deal_data: {str(e)}")
        print(f"Detailed traceback: {error_details}")
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/account")
async def account_data(accounts: List[AccountBase], db: Session = Depends(get_db)):
    try:
        raw_data = [account.model_dump() for account in accounts]
        save_data_to_file(raw_data, "accounts")

        for item in accounts:
            existing = db.query(Account).filter(Account.login == item.login).first()
            if existing:
                for key, value in item.model_dump().items():
                    setattr(existing, key, value)
            else:
                account = Account(**item.model_dump())
                db.add(account)

        db.commit()
        return {"message": "Account data saved successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/position")
async def position_data(positions: List[PositionBase], db: Session = Depends(get_db)):
    try:
        raw_data = [position.model_dump() for position in positions]
        save_data_to_file(raw_data, "positions")
        
        # Truncate the positions table
        db.execute(text("TRUNCATE TABLE positions"))

        # Insert only if the payload is not empty
        if positions:
            # Process each position and add Singapore time
            processed_data = []
            for item_data in raw_data:
                # Convert timestamps to Singapore time
                sg_time_data = {
                    'time_sg': convert_to_sg_time(item_data.get('time')),
                    'time_msc_sg': convert_to_sg_time(item_data.get('time_msc'), is_milliseconds=True),
                    'time_update_sg': convert_to_sg_time(item_data.get('time_update')),
                    'time_update_msc_sg': convert_to_sg_time(item_data.get('time_update_msc'), is_milliseconds=True)
                }
                
                # Add Singapore time fields to data
                item_data.update(sg_time_data)
                processed_data.append(item_data)
                
            db.bulk_insert_mappings(Position, processed_data)

        db.commit()
        return {"message": "Position table replaced successfully"}
    
    except Exception as e:
        error_details = traceback.format_exc()
        print(f"Error in position_data: {str(e)}")
        print(f"Detailed traceback: {error_details}")
        db.rollback()
        raise HTTPException(status_code=400, detail="Failed to update positions")

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
    print("Server started at http://127.0.0.1:8000")
