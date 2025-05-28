from rest_framework import serializers
from .models import Category, Transaction

class CategorySerializer(serializers.ModelSerializer):
    transaction_count = serializers.SerializerMethodField()
    total_amount = serializers.SerializerMethodField()
    
    class Meta:
        model = Category
        fields = ['id', 'name', 'type', 'color', 'created_at', 'transaction_count', 'total_amount']
        read_only_fields = ['id', 'created_at']
    
    def get_transaction_count(self, obj):
        return obj.transactions.count()
    
    def get_total_amount(self, obj):
        total = obj.transactions.aggregate(total=serializers.models.Sum('amount'))['total']
        return total or 0
    
    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)

class TransactionSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_color = serializers.CharField(source='category.color', read_only=True)
    type_display = serializers.CharField(source='get_type_display', read_only=True)
    
    class Meta:
        model = Transaction
        fields = [
            'id', 'amount', 'description', 'type', 'date', 
            'category', 'category_name', 'category_color', 'type_display',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'type', 'created_at', 'updated_at']
    
    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)
    
    def validate_category(self, value):
        # Ensure user can only use their own categories
        if value.user != self.context['request'].user:
            raise serializers.ValidationError("You can only use your own categories")
        return value

class TransactionSummarySerializer(serializers.Serializer):
    total_income = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_expenses = serializers.DecimalField(max_digits=12, decimal_places=2)
    net_balance = serializers.DecimalField(max_digits=12, decimal_places=2)
    income_by_category = serializers.ListField()
    expenses_by_category = serializers.ListField()
    monthly_trend = serializers.ListField()
    recent_transactions = TransactionSerializer(many=True)

class CategorySummarySerializer(serializers.Serializer):
    name = serializers.CharField()
    amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    color = serializers.CharField()
    percentage = serializers.FloatField()

class MonthlyTrendSerializer(serializers.Serializer):
    month = serializers.CharField()
    income = serializers.DecimalField(max_digits=12, decimal_places=2)
    expenses = serializers.DecimalField(max_digits=12, decimal_places=2)
    net = serializers.DecimalField(max_digits=12, decimal_places=2)