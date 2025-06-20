from fastapi import FastAPI, HTTPException, Request, Depends
from sqlalchemy.orm import Session
from database.database import SessionLocal
from database.data_models import Order, Deal, Position, Account
from pydantic_models import OrderBase, DealBase, PositionBase, AccountBase
from typing import List
import os
import json

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

@app.post("/ping")
async def ping():
    print("Received ping from MT5")
    return {"status": "OK"}

@app.post("/open")
async def open_order_data(orders: List[OrderBase], db: Session = Depends(get_db)):
    try:
        # Save raw JSON data to a file as list of dicts, not double JSON string
        raw_data = [order.dict() for order in orders]
        save_data_to_file(raw_data, "orders")
            
        for item in orders:
            existing = db.query(Order).filter(Order.ticket == item.ticket).first()
            if existing:
                for key, value in item.dict().items():
                    setattr(existing, key, value)
            else:
                order = Order(**item.dict())
                db.add(order)

        db.commit()
        return {"message": "Open order data saved successfully"}
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"Error in open_order_data: {str(e)}")
        print(f"Detailed traceback: {error_details}")
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/close")
async def close_order_data(deals: List[DealBase], db: Session = Depends(get_db)):
    try:
        raw_data = [deal.dict() for deal in deals]
        save_data_to_file(raw_data, "deals")
        
        for item in deals:
            existing = db.query(Deal).filter(Deal.ticket == item.ticket).first()
            if existing:
                for key, value in item.dict().items():
                    setattr(existing, key, value)
            else:
                deal = Deal(**item.dict())
                db.add(deal)

        db.commit()
        return {"message": "Close order data saved successfully"}
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"Error in close_order_data: {str(e)}")
        print(f"Detailed traceback: {error_details}")
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/account")
async def account_data(accounts: List[AccountBase], db: Session = Depends(get_db)):
    try:
        raw_data = [account.dict() for account in accounts]
        save_data_to_file(raw_data, "accounts")

        for item in accounts:
            existing = db.query(Account).filter(Account.login == item.login).first()
            if existing:
                for key, value in item.dict().items():
                    setattr(existing, key, value)
            else:
                account = Account(**item.dict())
                db.add(account)

        db.commit()
        return {"message": "Account data saved successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/position")
async def position_data(positions: List[PositionBase], db: Session = Depends(get_db)):
    try:
        raw_data = [position.dict() for position in positions]
        save_data_to_file(raw_data, "positions")
        
        for item in positions:
            existing = db.query(Position).filter(Position.ticket == item.ticket).first()
            if existing:
                for key, value in item.dict().items():
                    setattr(existing, key, value)
            else:
                position = Position(**item.dict())
                db.add(position)

        db.commit()
        return {"message": "Position data saved successfully"}
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"Error in position_data: {str(e)}")
        print(f"Detailed traceback: {error_details}")
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
    print("Server started at http://127.0.1:8000")
    