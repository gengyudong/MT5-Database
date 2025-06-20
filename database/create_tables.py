from database_connection import engine
from data_models import Base

Base.metadata.create_all(bind=engine)
