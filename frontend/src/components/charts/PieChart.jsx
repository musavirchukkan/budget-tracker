import React, { useEffect, useRef } from 'react';
import * as d3 from 'd3';

const PieChart = ({ data, colorField = 'color', width = 400, height = 300 }) => {
  const svgRef = useRef();

  useEffect(() => {
    if (!data || data.length === 0) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll('*').remove(); // Clear previous chart

    const margin = { top: 20, right: 20, bottom: 20, left: 20 };
    const chartWidth = width - margin.left - margin.right;
    const chartHeight = height - margin.top - margin.bottom;
    const radius = Math.min(chartWidth, chartHeight) / 2;

    const g = svg
      .attr('width', width)
      .attr('height', height)
      .append('g')
      .attr('transform', `translate(${width / 2}, ${height / 2})`);

    // Create pie layout
    const pie = d3.pie()
      .value(d => d.amount)
      .sort(null);

    // Create arc generator
    const arc = d3.arc()
      .innerRadius(0)
      .outerRadius(radius - 10);

    const outerArc = d3.arc()
      .innerRadius(radius - 10)
      .outerRadius(radius);

    // Create tooltip
    const tooltip = d3.select('body').selectAll('.pie-tooltip')
      .data([0])
      .join('div')
      .attr('class', 'pie-tooltip')
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

    // Create pie slices
    const slices = g.selectAll('.slice')
      .data(pie(data))
      .enter()
      .append('g')
      .attr('class', 'slice');

    // Add paths with animation
    slices.append('path')
      .attr('d', arc)
      .attr('fill', d => d.data[colorField] || '#3B82F6')
      .attr('stroke', '#fff')
      .attr('stroke-width', 2)
      .style('cursor', 'pointer')
      .on('mouseover', function(event, d) {
        // Highlight slice
        d3.select(this)
          .transition()
          .duration(200)
          .attr('transform', 'scale(1.05)');

        // Show tooltip
        tooltip
          .style('opacity', 1)
          .html(`
            <strong>${d.data.name}</strong><br/>
            Amount: ${formatCurrency(d.data.amount)}<br/>
            Percentage: ${d.data.percentage}%
          `)
          .style('left', (event.pageX + 10) + 'px')
          .style('top', (event.pageY - 10) + 'px');
      })
      .on('mouseout', function(event, d) {
        // Remove highlight
        d3.select(this)
          .transition()
          .duration(200)
          .attr('transform', 'scale(1)');

        // Hide tooltip
        tooltip.style('opacity', 0);
      })
      .transition()
      .duration(1000)
      .attrTween('d', function(d) {
        const interpolate = d3.interpolate({ startAngle: 0, endAngle: 0 }, d);
        return function(t) {
          return arc(interpolate(t));
        };
      });

    // Add percentage labels for slices > 5%
    slices.append('text')
      .attr('transform', d => `translate(${arc.centroid(d)})`)
      .attr('dy', '0.35em')
      .style('text-anchor', 'middle')
      .style('font-size', '12px')
      .style('font-weight', 'bold')
      .style('fill', '#fff')
      .style('text-shadow', '1px 1px 2px rgba(0,0,0,0.8)')
      .text(d => d.data.percentage > 5 ? `${d.data.percentage}%` : '')
      .style('opacity', 0)
      .transition()
      .delay(1000)
      .duration(500)
      .style('opacity', 1);

    // Add legend
    const legendHeight = 20;
    const legendSpacing = 4;
    const legend = svg.append('g')
      .attr('class', 'legend')
      .attr('transform', `translate(20, 20)`);

    const legendItems = legend.selectAll('.legend-item')
      .data(data)
      .enter()
      .append('g')
      .attr('class', 'legend-item')
      .attr('transform', (d, i) => `translate(0, ${i * (legendHeight + legendSpacing)})`);

    legendItems.append('rect')
      .attr('width', legendHeight)
      .attr('height', legendHeight)
      .attr('fill', d => d[colorField] || '#3B82F6')
      .attr('rx', 3);

    legendItems.append('text')
      .attr('x', legendHeight + 5)
      .attr('y', legendHeight / 2)
      .attr('dy', '0.35em')
      .style('font-size', '12px')
      .style('font-weight', '500')
      .style('fill', '#374151')
      .text(d => `${d.name} (${formatCurrency(d.amount)})`);

    // Cleanup function
    return () => {
      tooltip.remove();
    };
  }, [data, colorField, width, height]);

  if (!data || data.length === 0) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <div className="text-4xl mb-2">📊</div>
          <p className="text-gray-500">No data available</p>
        </div>
      </div>
    );
  }

  return <svg ref={svgRef}></svg>;
};

export default PieChart;