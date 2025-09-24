// Webpack Bundle Optimization Configuration
// This file should be integrated into the build process or used as a reference for Vite optimization

const path = require('path');
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
const CompressionPlugin = require('compression-webpack-plugin');
const TerserPlugin = require('terser-webpack-plugin');

module.exports = {
  optimization: {
    // Code splitting configuration
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        // Vendor libraries (React, etc.)
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          chunks: 'all',
          priority: 10,
        },
        
        // Common components shared across routes
        common: {
          minChunks: 2,
          chunks: 'all',
          name: 'common',
          priority: 5,
        },
        
        // UI library components (ShadCN, etc.)
        ui: {
          test: /[\\/]node_modules[\\/](@shadcn|@radix-ui)[\\/]/,
          name: 'ui-lib',
          chunks: 'all',
          priority: 8,
        },
        
        // Utility libraries
        utils: {
          test: /[\\/]src[\\/]utils[\\/]/,
          name: 'utils',
          chunks: 'all',
          priority: 6,
        },
        
        // CSS files
        styles: {
          test: /\.css$/,
          name: 'styles',
          chunks: 'all',
          priority: 7,
        }
      }
    },
    
    // Tree shaking and dead code elimination
    usedExports: true,
    sideEffects: false,
    
    // Minification
    minimizer: [
      new TerserPlugin({
        terserOptions: {
          compress: {
            drop_console: process.env.NODE_ENV === 'production',
            drop_debugger: true,
            pure_funcs: ['console.log', 'console.info', 'console.debug'],
          },
          mangle: {
            safari10: true,
          },
          format: {
            comments: false,
          },
        },
        extractComments: false,
      }),
    ],
  },
  
  // Performance hints
  performance: {
    maxEntrypointSize: 250000, // 250KB
    maxAssetSize: 250000,
    hints: process.env.NODE_ENV === 'production' ? 'warning' : false,
  },
  
  // Plugins for optimization
  plugins: [
    // Bundle analyzer (enable when needed)
    ...(process.env.ANALYZE_BUNDLE === 'true' ? [
      new BundleAnalyzerPlugin({
        analyzerMode: 'static',
        openAnalyzer: false,
        reportFilename: 'bundle-report.html',
      })
    ] : []),
    
    // Compression
    new CompressionPlugin({
      algorithm: 'gzip',
      test: /\.(js|css|html|svg)$/,
      threshold: 8192,
      minRatio: 0.8,
    }),
  ],
  
  // Module resolution optimization
  resolve: {
    extensions: ['.ts', '.tsx', '.js', '.jsx'],
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@components': path.resolve(__dirname, 'src/components'),
      '@utils': path.resolve(__dirname, 'src/utils'),
      '@hooks': path.resolve(__dirname, 'src/hooks'),
      '@services': path.resolve(__dirname, 'src/services'),
      '@types': path.resolve(__dirname, 'src/types'),
    },
    // Reduce resolution time
    modules: ['node_modules'],
    symlinks: false,
  },
  
  // Module optimization
  module: {
    rules: [
      // JavaScript/TypeScript optimization
      {
        test: /\.(js|jsx|ts|tsx)$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: [
              ['@babel/preset-env', {
                targets: {
                  browsers: ['> 1%', 'last 2 versions'],
                },
                modules: false, // Let webpack handle modules
                useBuiltIns: 'usage',
                corejs: 3,
              }],
              '@babel/preset-react',
              '@babel/preset-typescript',
            ],
            plugins: [
              // Dynamic imports
              '@babel/plugin-syntax-dynamic-import',
              
              // React optimizations
              ['babel-plugin-styled-components', {
                displayName: process.env.NODE_ENV !== 'production',
                minify: process.env.NODE_ENV === 'production',
              }],
              
              // Tree shaking for lodash
              ['babel-plugin-lodash'],
            ],
          },
        },
      },
      
      // CSS optimization
      {
        test: /\.css$/,
        use: [
          'style-loader',
          {
            loader: 'css-loader',
            options: {
              modules: {
                auto: true,
                localIdentName: process.env.NODE_ENV === 'production' 
                  ? '[hash:base64:5]' 
                  : '[name]__[local]--[hash:base64:5]',
              },
            },
          },
          'postcss-loader',
        ],
      },
      
      // Image optimization
      {
        test: /\.(png|jpe?g|gif|svg|webp)$/i,
        type: 'asset',
        parser: {
          dataUrlCondition: {
            maxSize: 8 * 1024, // 8KB
          },
        },
        generator: {
          filename: 'images/[name].[hash:8][ext]',
        },
        use: [
          {
            loader: 'image-webpack-loader',
            options: {
              mozjpeg: {
                progressive: true,
                quality: 65,
              },
              optipng: {
                enabled: false,
              },
              pngquant: {
                quality: [0.65, 0.90],
                speed: 4,
              },
              gifsicle: {
                interlaced: false,
              },
              webp: {
                quality: 75,
              },
            },
          },
        ],
      },
    ],
  },
  
  // Cache optimization
  cache: {
    type: 'filesystem',
    cacheDirectory: path.resolve(__dirname, '.webpack-cache'),
    buildDependencies: {
      config: [__filename],
    },
  },
};

// Vite-specific optimizations (vite.config.ts)
const viteOptimizations = {
  build: {
    // Rollup options for Vite
    rollupOptions: {
      output: {
        // Manual chunk splitting for better caching
        manualChunks: {
          'react-vendor': ['react', 'react-dom'],
          'ui-vendor': ['@radix-ui/react-dialog', '@radix-ui/react-dropdown-menu'],
          'router': ['react-router-dom'],
          'query': ['@tanstack/react-query'],
          'utils': ['lodash-es', 'date-fns'],
        },
        
        // Optimize chunk file names
        chunkFileNames: (chunkInfo) => {
          if (chunkInfo.name && chunkInfo.name.includes('vendor')) {
            return 'js/vendor-[name]-[hash].js';
          }
          return 'js/[name]-[hash].js';
        },
        
        assetFileNames: (assetInfo) => {
          if (assetInfo.name?.endsWith('.css')) {
            return 'css/[name]-[hash].css';
          }
          if (/\.(png|jpe?g|gif|svg|webp)$/i.test(assetInfo.name || '')) {
            return 'images/[name]-[hash][extname]';
          }
          return 'assets/[name]-[hash][extname]';
        },
      },
    },
    
    // Build target
    target: ['es2020', 'edge88', 'firefox78', 'chrome87', 'safari12'],
    
    // Source maps for production debugging
    sourcemap: process.env.NODE_ENV === 'development',
    
    // Minification
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: process.env.NODE_ENV === 'production',
        drop_debugger: true,
      },
    },
    
    // Chunk size warnings
    chunkSizeWarningLimit: 500, // 500KB
  },
  
  // Development server optimization
  server: {
    fs: {
      // Allow serving files outside of root
      allow: ['..'],
    },
    
    // HMR optimization
    hmr: {
      overlay: true,
    },
  },
  
  // Dependency optimization
  optimizeDeps: {
    include: [
      'react',
      'react-dom',
      'react-router-dom',
      '@tanstack/react-query',
      'lodash-es',
    ],
    exclude: [
      // Exclude large libraries that should be loaded dynamically
      'three',
      'chart.js',
    ],
  },
  
  // Define constants for better tree shaking
  define: {
    __DEV__: process.env.NODE_ENV === 'development',
    __PROD__: process.env.NODE_ENV === 'production',
    __VERSION__: JSON.stringify(process.env.npm_package_version),
  },
};

// Performance monitoring plugin
class PerformanceMonitoringPlugin {
  apply(compiler) {
    compiler.hooks.done.tap('PerformanceMonitoringPlugin', (stats) => {
      const compilation = stats.compilation;
      const assets = compilation.assets;
      
      console.log('\n📊 Bundle Performance Report:');
      console.log('============================');
      
      // Calculate total bundle size
      let totalSize = 0;
      const assetSizes = [];
      
      Object.keys(assets).forEach(name => {
        const asset = assets[name];
        const size = asset.size();
        totalSize += size;
        
        if (size > 100 * 1024) { // Show assets > 100KB
          assetSizes.push({ name, size });
        }
      });
      
      // Sort by size
      assetSizes.sort((a, b) => b.size - a.size);
      
      console.log(`Total Bundle Size: ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
      console.log('\nLarge Assets (>100KB):');
      assetSizes.forEach(({ name, size }) => {
        const sizeKB = (size / 1024).toFixed(2);
        console.log(`  ${name}: ${sizeKB} KB`);
      });
      
      // Performance warnings
      if (totalSize > 5 * 1024 * 1024) { // 5MB
        console.log('\n⚠️  Warning: Bundle size is very large (>5MB)');
      }
      
      // Build time
      const buildTime = stats.endTime - stats.startTime;
      console.log(`\nBuild Time: ${(buildTime / 1000).toFixed(2)}s`);
      console.log('============================\n');
    });
  }
}

module.exports = {
  webpackConfig: module.exports,
  viteOptimizations,
  PerformanceMonitoringPlugin,
};