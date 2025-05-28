import React, { useEffect, useRef } from 'react';
import * as d3 from 'd3';

const BarChart = ({ data, width = 600, height = 400 }) => {
  const svgRef = useRef();

  useEffect(() => {
    if (!data || data.length === 0) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll('*').remove(); // Clear previous chart

    const margin = { top: 20, right: 80, bottom: 60, left: 80 };
    const chartWidth = width - margin.left - margin.right;
    const chartHeight = height - margin.top - margin.bottom;

    // Create main group
    const g = svg
      .attr('width', width)
      .attr('height', height)
      .append('g')
      .attr('transform', `translate(${margin.left}, ${margin.top})`);

    // Scales
    const xScale = d3.scaleBand()
      .domain(data.map(d => d.category))
      .range([0, chartWidth])
      .padding(0.3);

    const yScale = d3.scaleLinear()
      .domain([0, d3.max([
        ...data.map(d => d.budget || 0),
        ...data.map(d => d.actual || 0)
      ])])
      .nice()
      .range([chartHeight, 0]);

    // Create tooltip
    const tooltip = d3.select('body').selectAll('.bar-tooltip')
      .data([0])
      .join('div')
      .attr('class', 'bar-tooltip')
      .style('position', 'absolute')
      .style('background', 'rgba(0, 0, 0, 0.8)')
      .style('color', 'white')
      .style('padding', '8px 12px')
      .style('border-radius', '4px')
      .style('font-size', '12px')
      .style('pointer-events', 'none')
      .style('opacity', 0)
      .style('z-index', 1000);

    // Format currency
    const formatCurrency = (amount) => {
      return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
      }).format(amount);
    };

    // Add axes
    const xAxis = d3.axisBottom(xScale);
    const yAxis = d3.axisLeft(yScale)
      .tickFormat(d => formatCurrency(d))
      .ticks(6);

    g.append('g')
      .attr('class', 'x-axis')
      .attr('transform', `translate(0, ${chartHeight})`)
      .call(xAxis)
      .selectAll('text')
      .style('font-size', '11px')
      .attr('transform', 'rotate(-45)')
      .style('text-anchor', 'end');

    g.append('g')
      .attr('class', 'y-axis')
      .call(yAxis)
      .selectAll('text')
      .style('font-size', '11px');

    // Add grid lines
    g.selectAll('.grid-line')
      .data(yScale.ticks(6))
      .enter()
      .append('line')
      .attr('class', 'grid-line')
      .attr('x1', 0)
      .attr('x2', chartWidth)
      .attr('y1', d => yScale(d))
      .attr('y2', d => yScale(d))
      .attr('stroke', '#e5e7eb')
      .attr('stroke-dasharray', '3,3')
      .attr('stroke-width', 1);

    // Grouped bar width
    const barWidth = xScale.bandwidth() / 2;

    // Budget bars
    g.selectAll('.budget-bar')
      .data(data)
      .enter()
      .append('rect')
      .attr('class', 'budget-bar')
      .attr('x', d => xScale(d.category))
      .attr('y', chartHeight)
      .attr('width', barWidth)
      .attr('height', 0)
      .attr('fill', '#3b82f6')
      .attr('opacity', 0.7)
      .style('cursor', 'pointer')
      .on('mouseover', function(event, d) {
        // Highlight bar
        d3.select(this).attr('opacity', 1);

        // Show tooltip
        tooltip
          .style('opacity', 1)
          .html(`
            <strong>${d.category}</strong><br/>
            Budget: ${formatCurrency(d.budget || 0)}<br/>
            Type: Budget
          `)
          .style('left', (event.pageX + 10) + 'px')
          .style('top', (event.pageY - 10) + 'px');
      })
      .on('mouseout', function() {
        d3.select(this).attr('opacity', 0.7);
        tooltip.style('opacity', 0);
      })
      .transition()
      .duration(1000)
      .delay((d, i) => i * 100)
      .attr('y', d => yScale(d.budget || 0))
      .attr('height', d => chartHeight - yScale(d.budget || 0));

    // Actual bars
    g.selectAll('.actual-bar')
      .data(data)
      .enter()
      .append('rect')
      .attr('class', 'actual-bar')
      .attr('x', d => xScale(d.category) + barWidth)
      .attr('y', chartHeight)
      .attr('width', barWidth)
      .attr('height', 0)
      .attr('fill', d => (d.actual || 0) > (d.budget || 0) ? '#ef4444' : '#10b981')
      .attr('opacity', 0.8)
      .style('cursor', 'pointer')
      .on('mouseover', function(event, d) {
        // Highlight bar
        d3.select(this).attr('opacity', 1);

        const isOverBudget = (d.actual || 0) > (d.budget || 0);
        const difference = Math.abs((d.actual || 0) - (d.budget || 0));

        // Show tooltip
        tooltip
          .style('opacity', 1)
          .html(`
            <strong>${d.category}</strong><br/>
            Actual: ${formatCurrency(d.actual || 0)}<br/>
            Budget: ${formatCurrency(d.budget || 0)}<br/>
            ${isOverBudget ? 'Over' : 'Under'} by: ${formatCurrency(difference)}<br/>
            Status: ${isOverBudget ? '⚠️ Over Budget' : '✅ Within Budget'}
          `)
          .style('left', (event.pageX + 10) + 'px')
          .style('top', (event.pageY - 10) + 'px');
      })
      .on('mouseout', function() {
        d3.select(this).attr('opacity', 0.8);
        tooltip.style('opacity', 0);
      })
      .transition()
      .duration(1000)
      .delay((d, i) => i * 100 + 500)
      .attr('y', d => yScale(d.actual || 0))
      .attr('height', d => chartHeight - yScale(d.actual || 0));

    // Add value labels on bars
    g.selectAll('.budget-label')
      .data(data)
      .enter()
      .append('text')
      .attr('class', 'budget-label')
      .attr('x', d => xScale(d.category) + barWidth / 2)
      .attr('y', d => yScale(d.budget || 0) - 5)
      .attr('text-anchor', 'middle')
      .style('font-size', '10px')
      .style('font-weight', 'bold')
      .style('fill', '#3b82f6')
      .text(d => formatCurrency(d.budget || 0))
      .style('opacity', 0)
      .transition()
      .delay(1500)
      .duration(500)
      .style('opacity', 1);

    g.selectAll('.actual-label')
      .data(data)
      .enter()
      .append('text')
      .attr('class', 'actual-label')
      .attr('x', d => xScale(d.category) + barWidth + barWidth / 2)
      .attr('y', d => yScale(d.actual || 0) - 5)
      .attr('text-anchor', 'middle')
      .style('font-size', '10px')
      .style('font-weight', 'bold')
      .style('fill', d => (d.actual || 0) > (d.budget || 0) ? '#ef4444' : '#10b981')
      .text(d => formatCurrency(d.actual || 0))
      .style('opacity', 0)
      .transition()
      .delay(1500)
      .duration(500)
      .style('opacity', 1);

    // Add legend
    const legend = svg.append('g')
      .attr('class', 'legend')
      .attr('transform', `translate(${width - 120}, 30)`);

    const legendData = [
      { label: 'Budget', color: '#3b82f6' },
      { label: 'Actual', color: '#10b981' },
      { label: 'Over Budget', color: '#ef4444' }
    ];

    const legendItems = legend.selectAll('.legend-item')
      .data(legendData)
      .enter()
      .append('g')
      .attr('class', 'legend-item')
      .attr('transform', (d, i) => `translate(0, ${i * 20})`);

    legendItems.append('rect')
      .attr('width', 15)
      .attr('height', 15)
      .attr('fill', d => d.color)
      .attr('opacity', 0.8);

    legendItems.append('text')
      .attr('x', 20)
      .attr('y', 7.5)
      .attr('dy', '0.35em')
      .style('font-size', '11px')
      .style('font-weight', '500')
      .style('fill', '#374151')
      .text(d => d.label);

    // Add axis labels
    g.append('text')
      .attr('class', 'x-label')
      .attr('text-anchor', 'middle')
      .attr('x', chartWidth / 2)
      .attr('y', chartHeight + 50)
      .style('font-size', '12px')
      .style('fill', '#6b7280')
      .text('Categories');

    g.append('text')
      .attr('class', 'y-label')
      .attr('text-anchor', 'middle')
      .attr('transform', 'rotate(-90)')
      .attr('x', -chartHeight / 2)
      .attr('y', -50)
      .style('font-size', '12px')
      .style('fill', '#6b7280')
      .text('Amount ($)');

    // Add title
    svg.append('text')
      .attr('class', 'chart-title')
      .attr('text-anchor', 'middle')
      .attr('x', width / 2)
      .attr('y', 15)
      .style('font-size', '14px')
      .style('font-weight', 'bold')
      .style('fill', '#1f2937')
      .text('Budget vs Actual Spending');

    // Cleanup function
    return () => {
      tooltip.remove();
    };
  }, [data, width, height]);

  if (!data || data.length === 0) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <div className="text-4xl mb-2">📊</div>
          <p className="text-gray-500">No budget comparison data available</p>
        </div>
      </div>
    );
  }

  return <svg ref={svgRef}></svg>;
};

export default BarChart;