#!/usr/bin/env python3
"""
Generate SVG files from Mermaid diagrams
"""
import os
import re

# Define all SVG diagrams
svg_diagrams = {
    "diagram1_key_findings": '''<svg width="600" height="200" xmlns="http://www.w3.org/2000/svg">
  <rect width="600" height="200" fill="#ffffff"/>
  <!-- AI Developer (center) -->
  <rect x="250" y="80" width="100" height="40" rx="5" fill="#e0f2fe" stroke="#0284c7" stroke-width="4"/>
  <text x="300" y="105" text-anchor="middle" font-family="Arial" font-size="14" fill="#000">AI Developer</text>
  
  <!-- US Developer -->
  <rect x="450" y="20" width="100" height="40" rx="5" fill="#fee2e2" stroke="#dc2626" stroke-width="2"/>
  <text x="500" y="45" text-anchor="middle" font-family="Arial" font-size="14" fill="#000">US Developer</text>
  
  <!-- Eastern Europe -->
  <rect x="450" y="80" width="120" height="40" rx="5" fill="#fed7aa" stroke="#ea580c" stroke-width="2"/>
  <text x="510" y="105" text-anchor="middle" font-family="Arial" font-size="14" fill="#000">Eastern Europe</text>
  
  <!-- India -->
  <rect x="450" y="140" width="100" height="40" rx="5" fill="#d1fae5" stroke="#059669" stroke-width="2"/>
  <text x="500" y="165" text-anchor="middle" font-family="Arial" font-size="14" fill="#000">India</text>
  
  <!-- Arrows with labels -->
  <path d="M 350 40 L 450 40" stroke="#666" stroke-width="2" marker-end="url(#arrowhead)"/>
  <text x="400" y="35" text-anchor="middle" font-family="Arial" font-size="12" fill="#666">23x cheaper</text>
  
  <path d="M 350 100 L 450 100" stroke="#666" stroke-width="2" marker-end="url(#arrowhead)"/>
  <text x="400" y="95" text-anchor="middle" font-family="Arial" font-size="12" fill="#666">8.3x cheaper</text>
  
  <path d="M 350 160 L 450 160" stroke="#666" stroke-width="2" marker-end="url(#arrowhead)"/>
  <text x="400" y="155" text-anchor="middle" font-family="Arial" font-size="12" fill="#666">6.7x cheaper</text>
  
  <!-- Arrow marker definition -->
  <defs>
    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
      <polygon points="0 0, 10 3.5, 0 7" fill="#666"/>
    </marker>
  </defs>
</svg>''',

    "diagram2_annual_cost": '''<svg width="500" height="400" xmlns="http://www.w3.org/2000/svg">
  <rect width="500" height="400" fill="#ffffff"/>
  <text x="250" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">Annual Cost Comparison (USD)</text>
  
  <!-- USA -->
  <rect x="50" y="70" width="180" height="80" rx="10" fill="#fee2e2" stroke="#dc2626" stroke-width="2"/>
  <text x="140" y="100" text-anchor="middle" font-family="Arial" font-size="20" fill="#000">🇺🇸 USA</text>
  <text x="140" y="130" text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000">$125,000</text>
  
  <!-- Eastern Europe -->
  <rect x="270" y="70" width="180" height="80" rx="10" fill="#fed7aa" stroke="#ea580c" stroke-width="2"/>
  <text x="360" y="100" text-anchor="middle" font-family="Arial" font-size="20" fill="#000">🇪🇺 Eastern Europe</text>
  <text x="360" y="130" text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000">$50,000</text>
  
  <!-- India -->
  <rect x="50" y="190" width="180" height="80" rx="10" fill="#d1fae5" stroke="#059669" stroke-width="2"/>
  <text x="140" y="220" text-anchor="middle" font-family="Arial" font-size="20" fill="#000">🇮🇳 India</text>
  <text x="140" y="250" text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000">$12,000</text>
  
  <!-- AI Developer -->
  <rect x="270" y="190" width="180" height="80" rx="10" fill="#e0f2fe" stroke="#0284c7" stroke-width="3"/>
  <text x="360" y="220" text-anchor="middle" font-family="Arial" font-size="20" fill="#000">🤖 AI Developer</text>
  <text x="360" y="250" text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000">$36,500</text>
</svg>''',

    "diagram3_startup_savings": '''<svg width="400" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="400" height="300" fill="#ffffff"/>
  <text x="200" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#1f2937">Startup Cost Savings with AI Developer</text>
  
  <!-- Pie Chart -->
  <g transform="translate(200, 170)">
    <!-- Development Cost (14% = 50.4 degrees) -->
    <path d="M 0,-80 A 80,80 0 0,1 77.3,20.9 L 0,0 Z" fill="#fef3c7" stroke="#f59e0b" stroke-width="2"/>
    
    <!-- Saved Budget (86% = 309.6 degrees) -->
    <path d="M 77.3,20.9 A 80,80 0 1,1 -0.1,-80 L 0,0 Z" fill="#d1fae5" stroke="#059669" stroke-width="2"/>
    
    <!-- Labels -->
    <text x="40" y="-20" text-anchor="middle" font-size="14" font-weight="bold" fill="#1f2937">14%</text>
    <text x="-30" y="20" text-anchor="middle" font-size="14" font-weight="bold" fill="#1f2937">86%</text>
  </g>
  
  <!-- Legend -->
  <g transform="translate(50, 260)">
    <rect x="0" y="0" width="20" height="15" fill="#fef3c7" stroke="#f59e0b"/>
    <text x="25" y="12" font-size="14" fill="#1f2937">Development: $4,500 (14%)</text>
    
    <rect x="200" y="0" width="20" height="15" fill="#d1fae5" stroke="#059669"/>
    <text x="225" y="12" font-size="14" fill="#1f2937">Saved Budget: $26,750 (86%)</text>
  </g>
</svg>''',

    "diagram4_monthly_cost": '''<svg width="600" height="200" xmlns="http://www.w3.org/2000/svg">
  <rect width="600" height="200" fill="#ffffff"/>
  <text x="300" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">Monthly Cost for 40 hours</text>
  
  <!-- Freelance US Dev -->
  <rect x="20" y="60" width="120" height="80" rx="5" fill="#f9fafb" stroke="#d1d5db" stroke-width="2"/>
  <text x="80" y="90" text-anchor="middle" font-family="Arial" font-size="12" fill="#000">Freelance US Dev</text>
  <text x="80" y="115" text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000">$4,000</text>
  
  <!-- Freelance Eastern EU -->
  <rect x="160" y="60" width="120" height="80" rx="5" fill="#f9fafb" stroke="#d1d5db" stroke-width="2"/>
  <text x="220" y="90" text-anchor="middle" font-family="Arial" font-size="12" fill="#000">Freelance Eastern EU</text>
  <text x="220" y="115" text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000">$1,600</text>
  
  <!-- Freelance India -->
  <rect x="300" y="60" width="120" height="80" rx="5" fill="#f9fafb" stroke="#d1d5db" stroke-width="2"/>
  <text x="360" y="90" text-anchor="middle" font-family="Arial" font-size="12" fill="#000">Freelance India</text>
  <text x="360" y="115" text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000">$400</text>
  
  <!-- AI Developer -->
  <rect x="440" y="60" width="120" height="80" rx="5" fill="#d1fae5" stroke="#059669" stroke-width="4"/>
  <text x="500" y="90" text-anchor="middle" font-family="Arial" font-size="12" fill="#000">AI Developer</text>
  <text x="500" y="115" text-anchor="middle" font-family="Arial" font-size="16" font-weight="bold" fill="#000">$167</text>
</svg>''',

    "diagram5_timeline": '''<svg width="700" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="700" height="300" fill="#ffffff"/>
  <text x="350" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">AI Developer Task Completion Timeline</text>
  
  <!-- Time axis -->
  <line x1="50" y1="250" x2="650" y2="250" stroke="#666" stroke-width="2"/>
  
  <!-- Time labels -->
  <text x="50" y="270" font-size="12" fill="#666">0:00</text>
  <text x="150" y="270" font-size="12" fill="#666">2:00</text>
  <text x="250" y="270" font-size="12" fill="#666">4:00</text>
  <text x="350" y="270" font-size="12" fill="#666">6:00</text>
  <text x="450" y="270" font-size="12" fill="#666">8:00</text>
  <text x="550" y="270" font-size="12" fill="#666">10:00</text>
  <text x="650" y="270" font-size="12" fill="#666">13:00</text>
  
  <!-- Tasks -->
  <!-- TL Schema Definitions (37m) -->
  <rect x="50" y="60" width="30" height="20" rx="3" fill="#10b981" stroke="#059669"/>
  <text x="10" y="75" font-size="11" fill="#000">TL Schema</text>
  
  <!-- Basic Request Implementation (13m) -->
  <rect x="80" y="90" width="11" height="20" rx="3" fill="#10b981" stroke="#059669"/>
  <text x="10" y="105" font-size="11" fill="#000">Basic Request</text>
  
  <!-- Update Handling System (11m) -->
  <rect x="91" y="120" width="9" height="20" rx="3" fill="#10b981" stroke="#059669"/>
  <text x="10" y="135" font-size="11" fill="#000">Update System</text>
  
  <!-- Transcription State Management (8m) -->
  <rect x="100" y="150" width="7" height="20" rx="3" fill="#10b981" stroke="#059669"/>
  <text x="10" y="165" font-size="11" fill="#000">State Mgmt</text>
  
  <!-- Basic Testing Infrastructure (6h) -->
  <rect x="107" y="180" width="230" height="20" rx="3" fill="#10b981" stroke="#059669"/>
  <text x="10" y="195" font-size="11" fill="#000">Testing Infra</text>
  
  <!-- Basic Transcription Manager (6.5h) -->
  <rect x="337" y="210" width="250" height="20" rx="3" fill="#10b981" stroke="#059669"/>
  <text x="10" y="225" font-size="11" fill="#000">Transcription Mgr</text>
</svg>''',

    "diagram6_india_salaries": '''<svg width="500" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="500" height="300" fill="#ffffff"/>
  <text x="250" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">Annual Salaries in India (USD)</text>
  
  <!-- Bangalore -->
  <rect x="50" y="60" width="180" height="60" rx="8" fill="#f9fafb" stroke="#6b7280" stroke-width="2"/>
  <text x="140" y="85" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">Bangalore</text>
  <text x="140" y="105" text-anchor="middle" font-family="Arial" font-size="13" fill="#000">$8,000-$20,000</text>
  
  <!-- Mumbai -->
  <rect x="270" y="60" width="180" height="60" rx="8" fill="#f9fafb" stroke="#6b7280" stroke-width="2"/>
  <text x="360" y="85" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">Mumbai</text>
  <text x="360" y="105" text-anchor="middle" font-family="Arial" font-size="13" fill="#000">$6,700-$16,000</text>
  
  <!-- Hyderabad -->
  <rect x="50" y="140" width="180" height="60" rx="8" fill="#f9fafb" stroke="#6b7280" stroke-width="2"/>
  <text x="140" y="165" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">Hyderabad</text>
  <text x="140" y="185" text-anchor="middle" font-family="Arial" font-size="13" fill="#000">$6,000-$15,000</text>
  
  <!-- Delhi NCR -->
  <rect x="270" y="140" width="180" height="60" rx="8" fill="#f9fafb" stroke="#6b7280" stroke-width="2"/>
  <text x="360" y="165" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">Delhi NCR</text>
  <text x="360" y="185" text-anchor="middle" font-family="Arial" font-size="13" fill="#000">$6,000-$14,000</text>
</svg>''',

    "diagram7_cost_10_stories": '''<svg width="600" height="400" xmlns="http://www.w3.org/2000/svg">
  <rect width="600" height="400" fill="#ffffff"/>
  <text x="300" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">Cost for 10 User Stories</text>
  
  <!-- US Team -->
  <rect x="50" y="60" width="140" height="80" rx="8" fill="#fee2e2" stroke="#dc2626" stroke-width="2"/>
  <text x="120" y="85" text-anchor="middle" font-family="Arial" font-size="13" font-weight="bold" fill="#000">US Team</text>
  <text x="120" y="105" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">$2,083</text>
  <text x="120" y="125" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">(0.25 FTE)</text>
  
  <!-- Eastern Europe -->
  <rect x="210" y="60" width="140" height="80" rx="8" fill="#fed7aa" stroke="#ea580c" stroke-width="2"/>
  <text x="280" y="85" text-anchor="middle" font-family="Arial" font-size="13" font-weight="bold" fill="#000">Eastern Europe</text>
  <text x="280" y="105" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">$833</text>
  <text x="280" y="125" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">(0.25 FTE)</text>
  
  <!-- India -->
  <rect x="370" y="60" width="140" height="80" rx="8" fill="#d1fae5" stroke="#059669" stroke-width="2"/>
  <text x="440" y="85" text-anchor="middle" font-family="Arial" font-size="13" font-weight="bold" fill="#000">India</text>
  <text x="440" y="105" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">$200</text>
  <text x="440" y="125" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">(0.25 FTE)</text>
  
  <!-- AI Developer -->
  <rect x="210" y="220" width="140" height="80" rx="8" fill="#e0f2fe" stroke="#0284c7" stroke-width="4"/>
  <text x="280" y="245" text-anchor="middle" font-family="Arial" font-size="13" font-weight="bold" fill="#000">AI Developer</text>
  <text x="280" y="265" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">$91</text>
  <text x="280" y="285" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">(3% capacity)</text>
  
  <!-- Arrows -->
  <path d="M 120 140 L 280 220" stroke="#666" stroke-width="2" marker-end="url(#arrow1)"/>
  <text x="150" y="175" font-size="12" fill="#666">23x more</text>
  
  <path d="M 280 140 L 280 220" stroke="#666" stroke-width="2" marker-end="url(#arrow1)"/>
  <text x="290" y="180" font-size="12" fill="#666">9x more</text>
  
  <path d="M 440 140 L 280 220" stroke="#666" stroke-width="2" marker-end="url(#arrow1)"/>
  <text x="380" y="175" font-size="12" fill="#666">2.2x more</text>
  
  <defs>
    <marker id="arrow1" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
      <polygon points="0 0, 10 3.5, 0 7" fill="#666"/>
    </marker>
  </defs>
</svg>''',

    "diagram8_enterprise_cost": '''<svg width="500" height="350" xmlns="http://www.w3.org/2000/svg">
  <rect width="500" height="350" fill="#ffffff"/>
  <text x="250" y="30" text-anchor="middle" font-size="18" font-weight="bold" fill="#1f2937">Cost Distribution: Enterprise Development</text>
  <text x="250" y="50" text-anchor="middle" font-size="14" fill="#6b7280">(Monthly cost for 1,000 user stories)</text>
  
  <!-- Pie Chart -->
  <g transform="translate(250, 190)">
    <!-- US Team (63.2%) -->
    <path d="M 0,-100 A 100,100 0 1,1 -58.8,80.9 L 0,0 Z" fill="#fee2e2" stroke="#dc2626" stroke-width="2"/>
    
    <!-- Eastern Europe (25.3%) -->
    <path d="M -58.8,80.9 A 100,100 0 0,1 -95.1,-30.9 L 0,0 Z" fill="#fed7aa" stroke="#ea580c" stroke-width="2"/>
    
    <!-- India (7.6%) -->
    <path d="M -95.1,-30.9 A 100,100 0 0,1 -80.9,-58.8 L 0,0 Z" fill="#d1fae5" stroke="#059669" stroke-width="2"/>
    
    <!-- AI Developer (2.8%) -->
    <path d="M -80.9,-58.8 A 100,100 0 0,1 0,-100 L 0,0 Z" fill="#e0f2fe" stroke="#0284c7" stroke-width="3"/>
    
    <!-- Percentage labels -->
    <text x="30" y="-30" text-anchor="middle" font-size="14" font-weight="bold" fill="#1f2937">63.2%</text>
    <text x="-70" y="30" text-anchor="middle" font-size="12" fill="#1f2937">25.3%</text>
    <text x="-70" y="-45" text-anchor="middle" font-size="11" fill="#1f2937">7.6%</text>
    <text x="-20" y="-85" text-anchor="middle" font-size="10" fill="#1f2937">2.8%</text>
  </g>
  
  <!-- Legend -->
  <g transform="translate(30, 310)">
    <rect x="0" y="0" width="15" height="12" fill="#fee2e2" stroke="#dc2626"/>
    <text x="20" y="10" font-size="12" fill="#1f2937">US: $208,330</text>
    
    <rect x="120" y="0" width="15" height="12" fill="#fed7aa" stroke="#ea580c"/>
    <text x="140" y="10" font-size="12" fill="#1f2937">E. Europe: $83,330</text>
    
    <rect x="260" y="0" width="15" height="12" fill="#d1fae5" stroke="#059669"/>
    <text x="280" y="10" font-size="12" fill="#1f2937">India: $25,000</text>
    
    <rect x="370" y="0" width="15" height="12" fill="#e0f2fe" stroke="#0284c7"/>
    <text x="390" y="10" font-size="12" fill="#1f2937">AI: $9,090</text>
  </g>
</svg>''',

    "diagram9_doc_quality": '''<svg width="500" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="500" height="300" fill="#ffffff"/>
  <text x="250" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">Documentation Quality Score (out of 10)</text>
  
  <!-- AI Developer -->
  <rect x="50" y="60" width="180" height="80" rx="8" fill="#e0f2fe" stroke="#0284c7" stroke-width="4"/>
  <text x="140" y="85" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">AI Developer</text>
  <text x="140" y="105" text-anchor="middle" font-family="Arial" font-size="20" font-weight="bold" fill="#000">9/10</text>
  <text x="140" y="125" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">Complete coverage</text>
  
  <!-- US Average -->
  <rect x="270" y="60" width="180" height="80" rx="8" fill="#f9fafb" stroke="#6b7280" stroke-width="2"/>
  <text x="360" y="85" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">US Average</text>
  <text x="360" y="105" text-anchor="middle" font-family="Arial" font-size="20" font-weight="bold" fill="#000">6/10</text>
  <text x="360" y="125" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">Often incomplete</text>
  
  <!-- Eastern Europe -->
  <rect x="50" y="160" width="180" height="80" rx="8" fill="#f9fafb" stroke="#6b7280" stroke-width="2"/>
  <text x="140" y="185" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">Eastern Europe</text>
  <text x="140" y="205" text-anchor="middle" font-family="Arial" font-size="20" font-weight="bold" fill="#000">5/10</text>
  <text x="140" y="225" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">Basic coverage</text>
  
  <!-- India -->
  <rect x="270" y="160" width="180" height="80" rx="8" fill="#f9fafb" stroke="#6b7280" stroke-width="2"/>
  <text x="360" y="185" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">India</text>
  <text x="360" y="205" text-anchor="middle" font-family="Arial" font-size="20" font-weight="bold" fill="#000">4/10</text>
  <text x="360" y="225" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">Minimal docs</text>
</svg>''',

    "diagram10_availability": '''<svg width="600" height="250" xmlns="http://www.w3.org/2000/svg">
  <rect width="600" height="250" fill="#ffffff"/>
  <text x="300" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">Annual Availability (Hours)</text>
  
  <!-- Human Developer -->
  <rect x="50" y="70" width="200" height="100" rx="10" fill="#f9fafb" stroke="#6b7280" stroke-width="2"/>
  <text x="150" y="100" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">Human Developer</text>
  <text x="150" y="125" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">1,760 hrs</text>
  <text x="150" y="145" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">(220 days × 8 hrs)</text>
  
  <!-- AI Developer -->
  <rect x="350" y="70" width="200" height="100" rx="10" fill="#e0f2fe" stroke="#0284c7" stroke-width="4"/>
  <text x="450" y="100" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">AI Developer</text>
  <text x="450" y="125" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">8,760 hrs</text>
  <text x="450" y="145" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">(365 days × 24 hrs)</text>
  
  <!-- Arrow -->
  <path d="M 250 120 L 350 120" stroke="#666" stroke-width="2" marker-end="url(#arrow2)"/>
  <text x="300" y="115" text-anchor="middle" font-size="12" fill="#666">5x less available</text>
  
  <defs>
    <marker id="arrow2" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
      <polygon points="0 0, 10 3.5, 0 7" fill="#666"/>
    </marker>
  </defs>
</svg>''',

    "diagram11_quality_time": '''<svg width="700" height="250" xmlns="http://www.w3.org/2000/svg">
  <rect width="700" height="250" fill="#ffffff"/>
  <text x="350" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">Code Quality Over Time</text>
  
  <!-- Hour 1 -->
  <rect x="50" y="70" width="90" height="80" rx="5" fill="#f3f4f6" stroke="#6b7280"/>
  <text x="95" y="95" text-anchor="middle" font-size="12" font-weight="bold" fill="#000">Hour 1</text>
  <text x="95" y="115" text-anchor="middle" font-size="11" fill="#000">AI: 100%</text>
  <text x="95" y="130" text-anchor="middle" font-size="11" fill="#000">Human: 100%</text>
  
  <!-- Hour 4 -->
  <rect x="160" y="70" width="90" height="80" rx="5" fill="#fef3c7" stroke="#f59e0b"/>
  <text x="205" y="95" text-anchor="middle" font-size="12" font-weight="bold" fill="#000">Hour 4</text>
  <text x="205" y="115" text-anchor="middle" font-size="11" fill="#000">AI: 100%</text>
  <text x="205" y="130" text-anchor="middle" font-size="11" fill="#000">Human: 95%</text>
  
  <!-- Hour 8 -->
  <rect x="270" y="70" width="90" height="80" rx="5" fill="#fed7aa" stroke="#ea580c"/>
  <text x="315" y="95" text-anchor="middle" font-size="12" font-weight="bold" fill="#000">Hour 8</text>
  <text x="315" y="115" text-anchor="middle" font-size="11" fill="#000">AI: 100%</text>
  <text x="315" y="130" text-anchor="middle" font-size="11" fill="#000">Human: 85%</text>
  
  <!-- Day 2 -->
  <rect x="380" y="70" width="90" height="80" rx="5" fill="#fdba74" stroke="#ea580c"/>
  <text x="425" y="95" text-anchor="middle" font-size="12" font-weight="bold" fill="#000">Day 2</text>
  <text x="425" y="115" text-anchor="middle" font-size="11" fill="#000">AI: 100%</text>
  <text x="425" y="130" text-anchor="middle" font-size="11" fill="#000">Human: 90%</text>
  
  <!-- Week 2 -->
  <rect x="490" y="70" width="90" height="80" rx="5" fill="#fb923c" stroke="#ea580c"/>
  <text x="535" y="95" text-anchor="middle" font-size="12" font-weight="bold" fill="#000">Week 2</text>
  <text x="535" y="115" text-anchor="middle" font-size="11" fill="#000">AI: 100%</text>
  <text x="535" y="130" text-anchor="middle" font-size="11" fill="#000">Human: 85%</text>
  
  <!-- Month 2 -->
  <rect x="600" y="70" width="90" height="80" rx="5" fill="#f97316" stroke="#ea580c"/>
  <text x="645" y="95" text-anchor="middle" font-size="12" font-weight="bold" fill="#000">Month 2</text>
  <text x="645" y="115" text-anchor="middle" font-size="11" fill="#000">AI: 100%</text>
  <text x="645" y="130" text-anchor="middle" font-size="11" fill="#000">Human: 80%</text>
  
  <!-- Arrows -->
  <path d="M 140 110 L 160 110" stroke="#666" stroke-width="2" marker-end="url(#arrow3)"/>
  <path d="M 250 110 L 270 110" stroke="#666" stroke-width="2" marker-end="url(#arrow3)"/>
  <path d="M 360 110 L 380 110" stroke="#666" stroke-width="2" marker-end="url(#arrow3)"/>
  <path d="M 470 110 L 490 110" stroke="#666" stroke-width="2" marker-end="url(#arrow3)"/>
  <path d="M 580 110 L 600 110" stroke="#666" stroke-width="2" marker-end="url(#arrow3)"/>
  
  <defs>
    <marker id="arrow3" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
      <polygon points="0 0, 10 3.5, 0 7" fill="#666"/>
    </marker>
  </defs>
</svg>''',

    "diagram12_5year_tco": '''<svg width="600" height="400" xmlns="http://www.w3.org/2000/svg">
  <rect width="600" height="400" fill="#ffffff"/>
  <text x="300" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">5-Year TCO Comparison</text>
  
  <!-- US Team -->
  <rect x="50" y="60" width="200" height="100" rx="10" fill="#fee2e2" stroke="#dc2626" stroke-width="2"/>
  <text x="150" y="90" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">US Team</text>
  <text x="150" y="115" text-anchor="middle" font-family="Arial" font-size="20" font-weight="bold" fill="#000">$625,000</text>
  <text x="150" y="140" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">5-year total</text>
  
  <!-- Eastern Europe -->
  <rect x="300" y="60" width="200" height="100" rx="10" fill="#fed7aa" stroke="#ea580c" stroke-width="2"/>
  <text x="400" y="90" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">Eastern Europe</text>
  <text x="400" y="115" text-anchor="middle" font-family="Arial" font-size="20" font-weight="bold" fill="#000">$250,000</text>
  <text x="400" y="140" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">5-year total</text>
  
  <!-- India -->
  <rect x="50" y="200" width="200" height="100" rx="10" fill="#d1fae5" stroke="#059669" stroke-width="2"/>
  <text x="150" y="230" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">India</text>
  <text x="150" y="255" text-anchor="middle" font-family="Arial" font-size="20" font-weight="bold" fill="#000">$60,000</text>
  <text x="150" y="280" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">5-year total</text>
  
  <!-- AI Developer -->
  <rect x="300" y="200" width="200" height="100" rx="10" fill="#e0f2fe" stroke="#0284c7" stroke-width="4"/>
  <text x="400" y="230" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">AI Developer</text>
  <text x="400" y="255" text-anchor="middle" font-family="Arial" font-size="20" font-weight="bold" fill="#000">$91,250</text>
  <text x="400" y="280" text-anchor="middle" font-family="Arial" font-size="11" fill="#666">5-year total</text>
  
  <!-- Comparison arrows -->
  <path d="M 150 160 L 400 200" stroke="#666" stroke-width="2" stroke-dasharray="5,5" marker-end="url(#arrow4)"/>
  <text x="250" y="175" text-anchor="middle" font-size="12" fill="#666">6.9x more</text>
  
  <path d="M 400 160 L 400 200" stroke="#666" stroke-width="2" stroke-dasharray="5,5" marker-end="url(#arrow4)"/>
  <text x="450" y="180" text-anchor="middle" font-size="12" fill="#666">2.7x more</text>
  
  <path d="M 150 250 L 300 250" stroke="#666" stroke-width="2" stroke-dasharray="5,5" marker-end="url(#arrow4)"/>
  <text x="225" y="245" text-anchor="middle" font-size="12" fill="#666">0.66x less</text>
  
  <defs>
    <marker id="arrow4" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
      <polygon points="0 0, 10 3.5, 0 7" fill="#666"/>
    </marker>
  </defs>
</svg>''',

    "diagram13_evolution": '''<svg width="600" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="600" height="300" fill="#ffffff"/>
  <text x="300" y="30" text-anchor="middle" font-family="Arial" font-size="18" font-weight="bold" fill="#000">Software Development Evolution</text>
  
  <!-- Past -->
  <rect x="50" y="80" width="150" height="80" rx="10" fill="#f9fafb" stroke="#6b7280" stroke-width="2"/>
  <text x="125" y="110" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">Past</text>
  <text x="125" y="135" text-anchor="middle" font-family="Arial" font-size="12" fill="#000">100% Human</text>
  
  <!-- Present -->
  <rect x="225" y="80" width="150" height="80" rx="10" fill="#f9fafb" stroke="#6b7280" stroke-width="2"/>
  <text x="300" y="110" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">Present</text>
  <text x="300" y="135" text-anchor="middle" font-family="Arial" font-size="12" fill="#000">10% AI, 90% Human</text>
  
  <!-- Future -->
  <rect x="400" y="80" width="150" height="80" rx="10" fill="#e0f2fe" stroke="#0284c7" stroke-width="4"/>
  <text x="475" y="110" text-anchor="middle" font-family="Arial" font-size="14" font-weight="bold" fill="#000">Future</text>
  <text x="475" y="135" text-anchor="middle" font-family="Arial" font-size="12" fill="#000">70% AI, 30% Human</text>
  
  <!-- Arrows -->
  <path d="M 200 120 L 225 120" stroke="#666" stroke-width="3" marker-end="url(#arrow5)"/>
  <path d="M 375 120 L 400 120" stroke="#666" stroke-width="3" marker-end="url(#arrow5)"/>
  
  <defs>
    <marker id="arrow5" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
      <polygon points="0 0, 10 3.5, 0 7" fill="#666"/>
    </marker>
  </defs>
</svg>'''
}

def create_markdown_with_svgs():
    """Replace Mermaid diagrams with SVG in the markdown file"""
    # Read the original file
    with open('/Users/alexanderfedin/Projects/demo/AI-Developer-ROI-Report-2025.md', 'r') as f:
        content = f.read()
    
    # Replace each Mermaid block with corresponding SVG
    replacements = [
        # Diagram 1
        (r'```mermaid\ngraph LR\n    A\[AI Developer\].*?```', svg_diagrams["diagram1_key_findings"]),
        # Diagram 2
        (r'```mermaid\n%%{init:.*?graph TD\n    subgraph "Annual Cost Comparison \(USD\)".*?```', svg_diagrams["diagram2_annual_cost"]),
        # Diagram 3
        (r'```mermaid\npie title "Startup Cost Savings with AI Developer".*?```', svg_diagrams["diagram3_startup_savings"]),
        # Diagram 4
        (r'```mermaid\n%%{init:.*?graph LR\n    subgraph "Monthly Cost for 40 hours".*?```', svg_diagrams["diagram4_monthly_cost"]),
        # Diagram 5
        (r'```mermaid\ngantt.*?```', svg_diagrams["diagram5_timeline"]),
        # Diagram 6
        (r'```mermaid\n%%{init:.*?graph TD\n    subgraph "Annual Salaries in India \(USD\)".*?```', svg_diagrams["diagram6_india_salaries"]),
        # Diagram 7
        (r'```mermaid\n%%{init:.*?graph TD\n    subgraph "Cost for 10 User Stories".*?```', svg_diagrams["diagram7_cost_10_stories"]),
        # Diagram 8
        (r'```mermaid\npie title "Cost Distribution: Enterprise Development".*?```', svg_diagrams["diagram8_enterprise_cost"]),
        # Diagram 9
        (r'```mermaid\n%%{init:.*?graph TD\n    subgraph "Documentation Quality Score \(out of 10\)".*?```', svg_diagrams["diagram9_doc_quality"]),
        # Diagram 10
        (r'```mermaid\n%%{init:.*?graph LR\n    subgraph "Annual Availability \(Hours\)".*?```', svg_diagrams["diagram10_availability"]),
        # Diagram 11
        (r'```mermaid\n%%{init:.*?graph LR\n    subgraph "Code Quality Over Time".*?```', svg_diagrams["diagram11_quality_time"]),
        # Diagram 12
        (r'```mermaid\n%%{init:.*?graph TD\n    subgraph "5-Year TCO Comparison".*?```', svg_diagrams["diagram12_5year_tco"]),
        # Diagram 13
        (r'```mermaid\n%%{init:.*?graph TD\n    subgraph "Software Development Evolution".*?```', svg_diagrams["diagram13_evolution"])
    ]
    
    # Apply replacements
    for pattern, svg in replacements:
        content = re.sub(pattern, svg, content, flags=re.DOTALL)
    
    # Save as new file
    output_file = '/Users/alexanderfedin/Projects/demo/AI-Developer-ROI-Report-2025-SVG.md'
    with open(output_file, 'w') as f:
        f.write(content)
    
    print(f"Created: {output_file}")
    
    # Also save individual SVG files
    svg_dir = '/Users/alexanderfedin/Projects/demo/svg-diagrams'
    os.makedirs(svg_dir, exist_ok=True)
    
    for name, svg_content in svg_diagrams.items():
        svg_file = os.path.join(svg_dir, f"{name}.svg")
        with open(svg_file, 'w') as f:
            f.write(svg_content)
        print(f"Created: {svg_file}")

if __name__ == "__main__":
    create_markdown_with_svgs()
    print("\nAll SVG diagrams have been created!")
    print("- Markdown with embedded SVGs: AI-Developer-ROI-Report-2025-SVG.md")
    print("- Individual SVG files: svg-diagrams/")