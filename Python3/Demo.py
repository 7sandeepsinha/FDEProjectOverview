
from dataclasses import dataclass


# A plain class: we write __init__ and __repr__ by hand. There is no __eq__,
# so == falls back to asking "is this the very same object?"
class Case:
    def __init__(self, case_id, order_id, order_status, promised_date):
        self.case_id = case_id
        self.order_id = order_id
        self.order_status = order_status
        self.promised_date = promised_date

    def __repr__(self):
        # !r shows each value in quotes, so print(c) gives Case('C-1001', 'DELIVERED')
        return f"Case({self.case_id!r}, {self.order_status!r})"

# we can write a custom __eq__ method 
# for equality operator between objects of this class 


# The same record as a dataclass: Python writes __init__, __repr__ and __eq__ for us.
@dataclass
class CaseRecord:
    case_id: str
    order_id: str
    order_status: str
    promised_date: str


def show_plain_class() -> None:
    print("--- plain class ---")
    c = Case("C-1001", "O-5001", "DELIVERED", "2025-03-06")
    print(c)  # Case('C-1001', 'DELIVERED')
    print(c.order_status)  # DELIVERED
    b = Case("C-1001", "O-5001", "DELIVERED", "2025-03-06")
    print(c == b)  # False: same values, but two separate objects
    print(c is b)  # False: is always asks "same object?"
    same = c
    print(c is same)  # True: both names point at one object


def show_dataclass() -> None:
    print("--- dataclass ---")
    c = CaseRecord("C-1001", "O-5001", "DELIVERED", "2025-03-06")
    b = CaseRecord("C-1001", "O-5001", "DELIVERED", "2025-03-06")
    print(c == b)  # True: dataclass == compares the field values
    print(c is b)  # False: still two separate objects
    print("Printing data class c")
    print(c)


# Python has no === operator. Writing c === b is a SyntaxError.
# JavaScript's === means "equal value and same type"; in Python, == compares values
# and "is" checks whether two names point at the very same object.


def show_dict_failures() -> None:
    print("--- loose dictionary ---")
    case = {
        "case_id": "C-1002",
        "order_id": "O-5002",
        "order_status": "SHIPPED",
        "promised_date": "2025-03-07",
    }
    print(case.get("order_status"))  # None: a typo in the key, and no error
    case["order_status"] = "Delivered"
    print(case["order_status"] in {"DELIVERED", "CANCELLED"})  # False: wrong spelling
    print(case["order_status"])  # KeyError on purpose: the only loud failure


def main() -> None:
    print("Hello, world!")
    show_plain_class()
    show_dataclass()
    show_dict_failures()  # last, because it ends with a KeyError on purpose


if __name__ == "__main__":
    main()


