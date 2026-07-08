import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  TrendingUp, TrendingDown, DollarSign, Users,
  Activity, CreditCard, PieChart, BarChart3,
  Calendar, ArrowUpRight, ArrowDownRight,
  Briefcase, Shield, Car, Heart, Moon, Sun
} from 'lucide-react';
import MetricsCard from './components/MetricsCard';
import RevenueChart from './components/RevenueChart';
import CommissionBreakdown from './components/CommissionBreakdown';
import RecentTransactions from './components/RecentTransactions';
import PolicyDistribution from './components/PolicyDistribution';
import PerformanceMetrics from './components/PerformanceMetrics';
import LiveDataFeed from './components/LiveDataFeed';
import { useDashboardData } from './hooks/useDashboardData';
import { formatCurrency, formatPercentage } from './utils/formatters';

const Dashboard = () => {
  const [darkMode, setDarkMode] = useState(false);
  const [selectedPeriod, setSelectedPeriod] = useState('month');
  const { data, loading, error } = useDashboardData();

  useEffect(() => {
    if (darkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [darkMode]);

  const metrics = [
    {
      title: 'Total Revenue',
      value: data?.totalRevenue || 2845600,
      change: 12.5,
      trend: 'up',
      icon: DollarSign,
      color: 'gradient-1',
      sparklineData: [40, 45, 50, 48, 55, 60, 58, 65, 70, 75, 80, 85]
    },
    {
      title: 'Active Policies',
      value: data?.activePolicies || 1284,
      change: 8.2,
      trend: 'up',
      icon: Shield,
      color: 'gradient-2',
      sparklineData: [30, 35, 32, 38, 40, 42, 45, 48, 50, 52, 55, 58],
      format: 'number'
    },
    {
      title: 'Commission Earned',
      value: data?.commissionEarned || 385400,
      change: -3.4,
      trend: 'down',
      icon: CreditCard,
      color: 'gradient-3',
      sparklineData: [60, 55, 58, 52, 50, 48, 45, 47, 43, 45, 42, 40]
    },
    {
      title: 'Customer Growth',
      value: data?.customerGrowth || 23.8,
      change: 5.2,
      trend: 'up',
      icon: Users,
      color: 'gradient-4',
      sparklineData: [20, 22, 25, 28, 30, 32, 35, 38, 40, 42, 45, 48],
      format: 'percentage'
    }
  ];

  return (
    <div className={`min-h-screen transition-all duration-500 ${
      darkMode ? 'dark bg-gray-950' : 'bg-gradient-to-br from-gray-50 via-blue-50 to-purple-50'
    }`}>
      {/* Header */}
      <motion.header
        initial={{ y: -100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        className="sticky top-0 z-50 backdrop-blur-xl bg-white/70 dark:bg-gray-900/70 border-b border-gray-200/50 dark:border-gray-800/50"
      >
        <div className="container mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <motion.div
                whileHover={{ rotate: 360 }}
                transition={{ duration: 0.5 }}
                className="w-10 h-10 bg-gradient-to-r from-blue-600 to-purple-600 rounded-xl flex items-center justify-center"
              >
                <BarChart3 className="w-6 h-6 text-white" />
              </motion.div>
              <div>
                <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
                  DrWise Financial Dashboard
                </h1>
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  Real-time insurance analytics & insights
                </p>
              </div>
            </div>

            <div className="flex items-center space-x-4">
              {/* Period Selector */}
              <div className="flex bg-gray-100 dark:bg-gray-800 rounded-lg p-1">
                {['day', 'week', 'month', 'year'].map((period) => (
                  <button
                    key={period}
                    onClick={() => setSelectedPeriod(period)}
                    className={`px-4 py-2 rounded-md text-sm font-medium transition-all ${
                      selectedPeriod === period
                        ? 'bg-white dark:bg-gray-700 text-blue-600 dark:text-blue-400 shadow-sm'
                        : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'
                    }`}
                  >
                    {period.charAt(0).toUpperCase() + period.slice(1)}
                  </button>
                ))}
              </div>

              {/* Dark Mode Toggle */}
              <motion.button
                whileTap={{ scale: 0.95 }}
                onClick={() => setDarkMode(!darkMode)}
                className="p-2 rounded-lg bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
              >
                {darkMode ? (
                  <Sun className="w-5 h-5 text-yellow-500" />
                ) : (
                  <Moon className="w-5 h-5 text-gray-700" />
                )}
              </motion.button>
            </div>
          </div>
        </div>
      </motion.header>

      {/* Main Content */}
      <div className="container mx-auto px-6 py-8">
        {/* Metrics Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          {metrics.map((metric, index) => (
            <motion.div
              key={metric.title}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
            >
              <MetricsCard {...metric} darkMode={darkMode} />
            </motion.div>
          ))}
        </div>

        {/* Charts Row 1 */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <motion.div
            className="lg:col-span-2"
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.3 }}
          >
            <RevenueChart darkMode={darkMode} period={selectedPeriod} />
          </motion.div>
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.4 }}
          >
            <CommissionBreakdown darkMode={darkMode} />
          </motion.div>
        </div>

        {/* Charts Row 2 */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.5 }}
          >
            <PolicyDistribution darkMode={darkMode} />
          </motion.div>
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.6 }}
          >
            <PerformanceMetrics darkMode={darkMode} />
          </motion.div>
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.7 }}
          >
            <LiveDataFeed darkMode={darkMode} />
          </motion.div>
        </div>

        {/* Recent Transactions */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8 }}
        >
          <RecentTransactions darkMode={darkMode} />
        </motion.div>
      </div>
    </div>
  );
};

export default Dashboard;