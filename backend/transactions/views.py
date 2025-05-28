from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.db.models import Sum, Q
from django.db.models.functions import TruncMonth
from datetime import datetime, timedelta
from decimal import Decimal
from .models import Transaction, Category
from .serializers import (
    TransactionSerializer, CategorySerializer, 
    TransactionSummarySerializer, CategorySummarySerializer,
    MonthlyTrendSerializer
)
from .filters import TransactionFilter

class CategoryListCreateView(generics.ListCreateAPIView):
    serializer_class = CategorySerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return Category.objects.filter(user=self.request.user)

class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CategorySerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return Category.objects.filter(user=self.request.user)

class TransactionListCreateView(generics.ListCreateAPIView):
    serializer_class = TransactionSerializer
    permission_classes = [IsAuthenticated]
    filterset_class = TransactionFilter
    search_fields = ['description', 'category__name']
    ordering_fields = ['date', 'amount', 'created_at']
    ordering = ['-date', '-created_at']
    
    def get_queryset(self):
        return Transaction.objects.filter(user=self.request.user).select_related('category')

class TransactionDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = TransactionSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return Transaction.objects.filter(user=self.request.user).select_related('category')

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def transaction_summary(request):
    """Get comprehensive financial summary for the user"""
    user = request.user
    
    # Get date range (default to last 12 months)
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=365)
    
    # Query parameters for date filtering
    start_param = request.GET.get('start_date')
    end_param = request.GET.get('end_date')
    
    if start_param:
        start_date = datetime.strptime(start_param, '%Y-%m-%d').date()
    if end_param:
        end_date = datetime.strptime(end_param, '%Y-%m-%d').date()
    
    # Base queryset
    transactions = Transaction.objects.filter(
        user=user,
        date__range=[start_date, end_date]
    ).select_related('category')
    
    # Calculate totals
    income_total = transactions.filter(type='income').aggregate(
        total=Sum('amount')
    )['total'] or Decimal('0.00')
    
    expense_total = transactions.filter(type='expense').aggregate(
        total=Sum('amount')
    )['total'] or Decimal('0.00')
    
    net_balance = income_total - expense_total
    
    # Income by category
    income_by_category = []
    income_categories = transactions.filter(type='income').values(
        'category__name', 'category__color'
    ).annotate(
        amount=Sum('amount')
    ).order_by('-amount')
    
    if income_total > 0:
        for item in income_categories:
            percentage = float((item['amount'] / income_total) * 100)
            income_by_category.append({
                'name': item['category__name'],
                'amount': item['amount'],
                'color': item['category__color'],
                'percentage': round(percentage, 1)
            })
    
    # Expenses by category
    expenses_by_category = []
    expense_categories = transactions.filter(type='expense').values(
        'category__name', 'category__color'
    ).annotate(
        amount=Sum('amount')
    ).order_by('-amount')
    
    if expense_total > 0:
        for item in expense_categories:
            percentage = float((item['amount'] / expense_total) * 100)
            expenses_by_category.append({
                'name': item['category__name'],
                'amount': item['amount'],
                'color': item['category__color'],
                'percentage': round(percentage, 1)
            })
    
    # Monthly trend (last 12 months)
    monthly_data = transactions.annotate(
        month=TruncMonth('date')
    ).values('month').annotate(
        income=Sum('amount', filter=Q(type='income')),
        expenses=Sum('amount', filter=Q(type='expense'))
    ).order_by('month')
    
    monthly_trend = []
    for item in monthly_data:
        income_amt = item['income'] or Decimal('0.00')
        expense_amt = item['expenses'] or Decimal('0.00')
        monthly_trend.append({
            'month': item['month'].strftime('%Y-%m'),
            'income': income_amt,
            'expenses': expense_amt,
            'net': income_amt - expense_amt
        })
    
    # Recent transactions
    recent_transactions = transactions.order_by('-date', '-created_at')[:10]
    
    summary_data = {
        'total_income': income_total,
        'total_expenses': expense_total,
        'net_balance': net_balance,
        'income_by_category': income_by_category,
        'expenses_by_category': expenses_by_category,
        'monthly_trend': monthly_trend,
        'recent_transactions': TransactionSerializer(recent_transactions, many=True).data
    }
    
    return Response(summary_data, status=status.HTTP_200_OK)