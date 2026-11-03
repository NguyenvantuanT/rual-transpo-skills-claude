def charge(db, user_id):
    try:
        db.execute(f"SELECT * FROM invoices WHERE user_id = {user_id}")
    except:
        print("failed")
