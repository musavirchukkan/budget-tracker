from django.db import models
from django.contrib.auth import get_user_model
from django.core.validators import MinValueValidator
from decimal import Decimal

User = get_user_model()

class Budget(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='budgets')
    category = models.ForeignKey('transactions.Category', on_delete=models.CASCADE, related_name='budgets')
    amount = models.DecimalField(
        max_digits=12, 
        decimal_places=2,
        validators=[MinValueValidator(Decimal('0.01'))]
    )
    month = models.DateField()  # Store as first day of the month
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ['user', 'category', 'month']
        ordering = ['-month', 'category__name']
        indexes = [
            models.Index(fields=['user', 'month']),
            models.Index(fields=['month']),
        ]
    
    def __str__(self):
        return f"{self.user.email} - {self.category.name}: ${self.amount} ({self.month.strftime('%B %Y')})"
    
    @property
    def month_year(self):
        return self.month.strftime('%B %Y')
    
    def get_actual_spent(self):
        """Get actual amount spent in this category for this month"""
        from transactions.models import Transaction
        
        transactions = Transaction.objects.filter(
            user=self.user,
            category=self.category,
            type='expense',
            date__year=self.month.year,
            date__month=self.month.month
        ).aggregate(total=models.Sum('amount'))
        
        return transactions['total'] or Decimal('0.00')
    
    @property
    def remaining_budget(self):
        """Get remaining budget amount"""
        actual = self.get_actual_spent()
        return self.amount - actual
    
    @property
    def percentage_used(self):
        """Get percentage of budget used"""
        actual = self.get_actual_spent()
        if self.amount == 0:
            return 0
        return (actual / self.amount) * 100
    
    @property
    def is_over_budget(self):
        """Check if over budget"""
        return self.get_actual_spent() > self.amount