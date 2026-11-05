"""
Python Exception Handling Demonstration
----------------------------------------
1. Basic try...except...else...finally syntax
2. Multiple exception types & exception object inspection
3. Custom Exception creation, raising, and handling
"""


# ==========================================
# 1. Basic Exception Handling
# ==========================================
def divide_numbers(numerator: float, denominator: float) -> None:
    try:
        # Code that might raise an exception
        result = numerator / denominator
    except ZeroDivisionError:
        # Triggered specifically when dividing by zero
        print("   [Error] Cannot divide by zero!")
    except TypeError as err:
        # Triggered when invalid data types are passed
        print(f"   [Error] Invalid data type provided: {err}")
    else:
        # Executes ONLY if no exception was raised in the try block
        print(f"   [Success] Result: {result}")
    finally:
        # Executes ALWAYS, regardless of exceptions (ideal for cleanup)
        print("   [Cleanup] Division check complete.")


# ==========================================
# 2. Multiple Exceptions & Object Inspection
# ==========================================
def parse_and_get_item(items: list, index_str: str) -> None:
    try:
        # String conversion can raise ValueError
        index = int(index_str)
        # List indexing can raise IndexError
        value = items[index]
        print(f"   [Success] Found item at index {index}: '{value}'")

    except (ValueError, IndexError) as err:
        # Catch multiple specific exceptions in a single block
        print(f"   [Lookup Failed] ({type(err).__name__}): {err}")
    except Exception as err:
        # Generic fallback for any other unforeseen exceptions
        print(f"   [Unexpected Error]: {err}")


# ==========================================
# 3. Custom Exception Creation & Usage
# ==========================================
class InsufficientFundsError(Exception):
    """Raised when a withdrawal amount exceeds the available account balance."""

    def __init__(self, balance: float, amount: float):
        self.balance = balance
        self.amount = amount
        self.shortfall = amount - balance
        # Pass a clear default message to the base Exception class
        super().__init__(
            f"Cannot withdraw ${amount:.2f}. "
            f"Available balance: ${balance:.2f} (Shortfall: ${self.shortfall:.2f})."
        )


class BankAccount:
    def __init__(self, owner: str, balance: float):
        self.owner = owner
        self.balance = balance

    def withdraw(self, amount: float) -> float:
        if amount <= 0:
            raise ValueError("Withdrawal amount must be greater than zero.")
        if amount > self.balance:
            # Raise custom exception when business rule fails
            raise InsufficientFundsError(self.balance, amount)

        self.balance -= amount
        return self.balance


# ==========================================
# Main Execution Runner
# ==========================================
if __name__ == "__main__":
    print("==========================================")
    print("--- 1. BASIC EXCEPTION HANDLING ---")
    print("==========================================")
    print("Attempting: 10 / 2")
    divide_numbers(10, 2)
    print()

    print("Attempting: 10 / 0")
    divide_numbers(10, 0)
    print()

    print("Attempting: 10 / '2'")
    divide_numbers(10, "2")
    print("\n")

    print("==========================================")
    print("--- 2. MULTIPLE EXCEPTIONS ---")
    print("==========================================")
    fruits = ["apple", "banana", "cherry"]
    print(f"Data list: {fruits}")

    print("\nAttempting index '1':")
    parse_and_get_item(fruits, "1")

    print("\nAttempting index 'abc':")
    parse_and_get_item(fruits, "abc")

    print("\nAttempting index '10':")
    parse_and_get_item(fruits, "10")
    print("\n")

    print("==========================================")
    print("--- 3. CUSTOM EXCEPTION ---")
    print("==========================================")
    account = BankAccount(owner="Alice", balance=150.00)
    print(f"Account created for {account.owner} with balance: ${account.balance:.2f}\n")

    # Step A: Successful withdrawal
    try:
        print("Attempting to withdraw $50.00...")
        account.withdraw(50.00)
        print(f"Withdrawal successful! Remaining balance: ${account.balance:.2f}\n")
    except InsufficientFundsError as err:
        print(f"Caught Custom Exception: {err}")

    # Step B: Triggering Custom Exception
    try:
        print("Attempting to withdraw $200.00...")
        account.withdraw(200.00)
    except InsufficientFundsError as err:
        print(f"\nCaught Custom Exception: {err}")
        print(f"Accessing custom property -> Shortfall amount: ${err.shortfall:.2f}")
    except ValueError as err:
        print(f"Invalid Operation: {err}")

    print("\n==========================================")
    print("All demonstrations executed successfully!")
    print("==========================================")