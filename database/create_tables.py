from database.database import engine
from database.data_models import Base

Base.metadata.create_all(bind=engine)
