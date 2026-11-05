"""An enum is a closed list of allowed values. Run it with: python enum_demo.py"""

from enum import StrEnum  # Python 3.11 or newer


class OrderStatus(StrEnum):
    PROCESSING = "PROCESSING"
    SHIPPED = "SHIPPED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"


print(list(OrderStatus))  # all four members, in order
print(OrderStatus.SHIPPED == "SHIPPED")  # True: a StrEnum compares like a string
print(OrderStatus.PROCESSING)  # PROCESSING: and prints like one
#OrderStatus("RETURNED")  # ValueError on purpose: RETURNED is not on the list