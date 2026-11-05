from datetime import date


def read_promised(raw: str) -> date:
    return date.fromisoformat(raw)


def check_row(row: dict[str, str]) -> str:
    try:
        promised = read_promised(row["promised_date"])
    except ValueError:
        return "quarantined: promised_date is not a date"
    else:
        return f"accepted, due {promised.isoformat()}"
    finally:
        print(f"checked {row['case_id']}")


print(check_row({"case_id": "C-3003", "promised_date": "07/03/2025"}))
print(check_row({"case_id": "C-3001", "promised_date": "2025-03-07"}))
