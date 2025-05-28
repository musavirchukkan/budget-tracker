import React, { useEffect, useRef } from 'react';
import * as d3 from 'd3';

const LineChart = ({ data, width = 800, height = 300 }) => {
  const svgRef = useRef();

  useEffect(() => {
    if (!data || data.length === 0) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll('*').remove(); // Clear previous chart

    const margin = { top: 20, right: 60, bottom: 40, left: 60 };
    const chartWidth = width - margin.left - margin.right;
    const chartHeight = height - margin.top - margin.bottom;

    // Create main group
    const g = svg
      .attr('width', width)
      .attr('height', height)
      .append('g')
      .attr('transform', `translate(${margin.left}, ${margin.top})`);

    // Parse dates and prepare data
    const parseTime = d3.timeParse('%Y-%m');
    const processedData = data.map(d => ({
      ...d,
      date: parseTime(d.month),
      income: +d.income,
      expenses: +d.expenses,
      net: +d.net
    })).sort((a, b) => a.date - b.date);

    // Scales
    const xScale = d3.scaleTime()
      .domain(d3.extent(processedData, d => d.date))
      .range([0, chartWidth]);

    const yScale = d3.scaleLinear()
      .domain(d3.extent([
        ...processedData.map(d => d.income),
        ...processedData.map(d => d.expenses),
        ...processedData.map(d => d.net),
        0
      ]))
      .range([chartHeight, 0]);

    // Line generators
    const incomeLine = d3.line()
      .x(d => xScale(d.date))
      .y(d => yScale(d.income))
      .curve(d3.curveMonotoneX);

    const expenseLine = d3.line()
      .x(d => xScale(d.date))
      .y(d => yScale(d.expenses))
      .curve(d3.curveMonotoneX);

    const netLine = d3.line()
      .x(d => xScale(d.date))
      .y(d => yScale(d.net))
      .curve(d3.curveMonotoneX);

    // Create tooltip
    const tooltip = d3.select('body').selectAll('.line-tooltip')
      .data([0])
      .join('div')
      .attr('class', 'line-tooltip')
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

    // Format month
    const formatMonth = d3.timeFormat('%b %Y');

    // Add axes
    const xAxis = d3.axisBottom(xScale)
      .tickFormat(d3.timeFormat('%b %Y'))
      .ticks(d3.timeMonth.every(1));

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
    g.selectAll('.grid-line-y')
      .data(yScale.ticks(6))
      .enter()
      .append('line')
      .attr('class', 'grid-line-y')
      .attr('x1', 0)
      .attr('x2', chartWidth)
      .attr('y1', d => yScale(d))
      .attr('y2', d => yScale(d))
      .attr('stroke', '#e5e7eb')
      .attr('stroke-dasharray', '3,3')
      .attr('stroke-width', 1);

    // Add zero line
    if (yScale.domain()[0] < 0 && yScale.domain()[1] > 0) {
      g.append('line')
        .attr('class', 'zero-line')
        .attr('x1', 0)
        .attr('x2', chartWidth)
        .attr('y1', yScale(0))
        .attr('y2', yScale(0))
        .attr('stroke', '#6b7280')
        .attr('stroke-width', 2);
    }

    // Add lines with animation
    const lines = [
      { data: processedData, line: incomeLine, color: '#10b981', label: 'Income', key: 'income' },
      { data: processedData, line: expenseLine, color: '#ef4444', label: 'Expenses', key: 'expenses' },
      { data: processedData, line: netLine, color: '#3b82f6', label: 'Net', key: 'net' }
    ];

    lines.forEach(({ data: lineData, line, color, label, key }) => {
      // Add line path
      const path = g.append('path')
        .datum(lineData)
        .attr('class', `line line-${key}`)
        .attr('fill', 'none')
        .attr('stroke', color)
        .attr('stroke-width', 3)
        .attr('d', line);

      // Animate line
      const totalLength = path.node().getTotalLength();
      path
        .attr('stroke-dasharray', totalLength + ' ' + totalLength)
        .attr('stroke-dashoffset', totalLength)
        .transition()
        .duration(2000)
        .ease(d3.easeLinear)
        .attr('stroke-dashoffset', 0);

      // Add dots
      const dots = g.selectAll(`.dot-${key}`)
        .data(lineData)
        .enter()
        .append('circle')
        .attr('class', `dot dot-${key}`)
        .attr('cx', d => xScale(d.date))
        .attr('cy', d => yScale(d[key]))
        .attr('r', 0)
        .attr('fill', color)
        .attr('stroke', '#fff')
        .attr('stroke-width', 2)
        .style('cursor', 'pointer')
        .on('mouseover', function(event, d) {
          // Highlight dot
          d3.select(this)
            .transition()
            .duration(200)
            .attr('r', 8);

          // Show tooltip
          tooltip
            .style('opacity', 1)
            .html(`
              <strong>${formatMonth(d.date)}</strong><br/>
              Income: ${formatCurrency(d.income)}<br/>
              Expenses: ${formatCurrency(d.expenses)}<br/>
              Net: ${formatCurrency(d.net)}
            `)
            .style('left', (event.pageX + 10) + 'px')
            .style('top', (event.pageY - 10) + 'px');
        })
        .on('mouseout', function() {
          // Remove highlight
          d3.select(this)
            .transition()
            .duration(200)
            .attr('r', 4);

          // Hide tooltip
          tooltip.style('opacity', 0);
        });

      // Animate dots
      dots.transition()
        .delay(2000)
        .duration(500)
        .attr('r', 4);
    });

    // Add legend
    const legend = svg.append('g')
      .attr('class', 'legend')
      .attr('transform', `translate(${width - 150}, 30)`);

    const legendItems = legend.selectAll('.legend-item')
      .data(lines)
      .enter()
      .append('g')
      .attr('class', 'legend-item')
      .attr('transform', (d, i) => `translate(0, ${i * 25})`);

    legendItems.append('line')
      .attr('x1', 0)
      .attr('x2', 20)
      .attr('y1', 0)
      .attr('y2', 0)
      .attr('stroke', d => d.color)
      .attr('stroke-width', 3);

    legendItems.append('text')
      .attr('x', 25)
      .attr('y', 0)
      .attr('dy', '0.35em')
      .style('font-size', '12px')
      .style('font-weight', '500')
      .style('fill', '#374151')
      .text(d => d.label);

    // Add axis labels
    g.append('text')
      .attr('class', 'x-label')
      .attr('text-anchor', 'middle')
      .attr('x', chartWidth / 2)
      .attr('y', chartHeight + 35)
      .style('font-size', '12px')
      .style('fill', '#6b7280')
      .text('Month');

    g.append('text')
      .attr('class', 'y-label')
      .attr('text-anchor', 'middle')
      .attr('transform', 'rotate(-90)')
      .attr('x', -chartHeight / 2)
      .attr('y', -40)
      .style('font-size', '12px')
      .style('fill', '#6b7280')
      .text('Amount ($)');

    // Cleanup function
    return () => {
      tooltip.remove();
    };
  }, [data, width, height]);

  if (!data || data.length === 0) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <div className="text-4xl mb-2">📈</div>
          <p className="text-gray-500">No trend data available</p>
        </div>
      </div>
    );
  }

  return <svg ref={svgRef}></svg>;
};

export default LineChart;