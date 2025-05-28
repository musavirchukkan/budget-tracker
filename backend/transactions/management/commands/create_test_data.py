from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from transactions.models import Category, Transaction
from budgets.models import Budget
from decimal import Decimal
from datetime import date, timedelta
import random

User = get_user_model()

class Command(BaseCommand):
    help = 'Create test data for the budget tracker application'

    def handle(self, *args, **options):
        self.stdout.write('Creating test data...')
        
        # Create test user
        user, created = User.objects.get_or_create(
            email='test@example.com',
            defaults={
                'username': 'testuser',
                'first_name': 'Test',
                'last_name': 'User',
            }
        )
        if created:
            user.set_password('testpass123')
            user.save()
            self.stdout.write(f'Created test user: {user.email}')
        else:
            self.stdout.write(f'Test user already exists: {user.email}')

        # Create categories
        income_categories = [
            ('Salary', '#10b981'),
            ('Freelance', '#059669'),
            ('Investment', '#047857'),
            ('Other Income', '#065f46'),
        ]
        
        expense_categories = [
            ('Food & Dining', '#ef4444'),
            ('Transportation', '#dc2626'),
            ('Shopping', '#b91c1c'),
            ('Entertainment', '#991b1b'),
            ('Bills & Utilities', '#7f1d1d'),
            ('Healthcare', '#f97316'),
            ('Education', '#ea580c'),
            ('Travel', '#c2410c'),
            ('Groceries', '#9a3412'),
            ('Rent', '#7c2d12'),
        ]

        # Create income categories
        for name, color in income_categories:
            category, created = Category.objects.get_or_create(
                name=name,
                type='income',
                user=user,
                defaults={'color': color}
            )
            if created:
                self.stdout.write(f'Created income category: {name}')

        # Create expense categories
        for name, color in expense_categories:
            category, created = Category.objects.get_or_create(
                name=name,
                type='expense',
                user=user,
                defaults={'color': color}
            )
            if created:
                self.stdout.write(f'Created expense category: {name}')

        # Get categories for transactions
        income_cats = Category.objects.filter(user=user, type='income')
        expense_cats = Category.objects.filter(user=user, type='expense')

        # Create transactions for the last 12 months
        end_date = date.today()
        start_date = end_date - timedelta(days=365)
        
        # Sample transaction data
        income_transactions = [
            ('Monthly Salary', 4500, 'Salary'),
            ('Freelance Project', 800, 'Freelance'),
            ('Stock Dividend', 150, 'Investment'),
            ('Side Hustle', 300, 'Other Income'),
        ]
        
        expense_transactions = [
            ('Grocery Shopping', 120, 'Groceries'),
            ('Restaurant Dinner', 45, 'Food & Dining'),
            ('Gas Station', 60, 'Transportation'),
            ('Netflix Subscription', 15, 'Entertainment'),
            ('Electric Bill', 85, 'Bills & Utilities'),
            ('Rent Payment', 1200, 'Rent'),
            ('Online Shopping', 75, 'Shopping'),
            ('Doctor Visit', 150, 'Healthcare'),
            ('Coffee Shop', 12, 'Food & Dining'),
            ('Movie Tickets', 25, 'Entertainment'),
            ('Uber Ride', 18, 'Transportation'),
            ('Phone Bill', 55, 'Bills & Utilities'),
            ('Gym Membership', 40, 'Healthcare'),
            ('Book Purchase', 30, 'Education'),
            ('Weekend Trip', 200, 'Travel'),
        ]

        # Generate monthly transactions
        current_date = start_date
        while current_date <= end_date:
            # Create income transactions (1-2 per month)
            for _ in range(random.randint(1, 2)):
                transaction_data = random.choice(income_transactions)
                description, base_amount, cat_name = transaction_data
                
                try:
                    category = income_cats.get(name=cat_name)
                    amount = Decimal(str(base_amount + random.randint(-100, 200)))
                    
                    Transaction.objects.get_or_create(
                        user=user,
                        category=category,
                        description=f"{description} - {current_date.strftime('%B %Y')}",
                        amount=amount,
                        type='income',
                        date=current_date + timedelta(days=random.randint(0, 28))
                    )
                except Category.DoesNotExist:
                    continue

            # Create expense transactions (8-15 per month)
            for _ in range(random.randint(8, 15)):
                transaction_data = random.choice(expense_transactions)
                description, base_amount, cat_name = transaction_data
                
                try:
                    category = expense_cats.get(name=cat_name)
                    amount = Decimal(str(base_amount + random.randint(-20, 50)))
                    
                    Transaction.objects.get_or_create(
                        user=user,
                        category=category,
                        description=description,
                        amount=amount,
                        type='expense',
                        date=current_date + timedelta(days=random.randint(0, 28))
                    )
                except Category.DoesNotExist:
                    continue
            
            # Move to next month
            if current_date.month == 12:
                current_date = current_date.replace(year=current_date.year + 1, month=1)
            else:
                current_date = current_date.replace(month=current_date.month + 1)

        # Create budgets for current month
        current_month = date.today().replace(day=1)
        
        budget_data = [
            ('Food & Dining', 300),
            ('Transportation', 200),
            ('Shopping', 150),
            ('Entertainment', 100),
            ('Bills & Utilities', 250),
            ('Healthcare', 100),
            ('Groceries', 400),
            ('Travel', 200),
        ]
        
        for cat_name, budget_amount in budget_data:
            try:
                category = expense_cats.get(name=cat_name)
                budget, created = Budget.objects.get_or_create(
                    user=user,
                    category=category,
                    month=current_month,
                    defaults={'amount': Decimal(str(budget_amount))}
                )
                if created:
                    self.stdout.write(f'Created budget for {cat_name}: ${budget_amount}')
            except Category.DoesNotExist:
                continue

        self.stdout.write(
            self.style.SUCCESS(
                f'Successfully created test data!\n'
                f'Test credentials:\n'
                f'Email: test@example.com\n'
                f'Password: testpass123'
            )
        )