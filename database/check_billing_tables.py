from check_cols import run_remote

out, err, code = run_remote("""sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c "SELECT * FROM billing_cycles;" """)
print("BILLING CYCLES:")
print(out)

out2, err2, code2 = run_remote("""sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c "SELECT * FROM quota_allocations;" """)
print("ALLOCATIONS:")
print(out2)
