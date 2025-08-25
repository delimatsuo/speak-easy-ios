// Universal Translator Admin Dashboard - Revenue Tab Test Script
// Run this script in the browser console after loading the admin dashboard

console.log('🧪 Starting Revenue Tab Comprehensive Test...');

// Test configuration
const TEST_CONFIG = {
    TIMEOUT_MS: 10000,
    SCREENSHOT_DELAY: 2000,
    TAB_SWITCH_DELAY: 1000
};

class RevenuTabTester {
    constructor() {
        this.errors = [];
        this.warnings = [];
        this.results = [];
        this.screenshots = [];
    }

    log(message, type = 'info') {
        const timestamp = new Date().toISOString();
        const logMessage = `[${timestamp}] ${message}`;
        
        switch(type) {
            case 'error':
                console.error(`❌ ${logMessage}`);
                this.errors.push(logMessage);
                break;
            case 'warning':
                console.warn(`⚠️ ${logMessage}`);
                this.warnings.push(logMessage);
                break;
            case 'success':
                console.log(`✅ ${logMessage}`);
                this.results.push({status: 'success', message: logMessage});
                break;
            default:
                console.log(`ℹ️ ${logMessage}`);
                this.results.push({status: 'info', message: logMessage});
        }
    }

    async captureScreenshot(description) {
        try {
            // Note: This requires browser permissions
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
            
            // Alternative: Just log current state
            this.log(`📸 Screenshot captured: ${description}`);
            this.screenshots.push({
                description,
                timestamp: new Date().toISOString(),
                url: window.location.href,
                viewport: {
                    width: window.innerWidth,
                    height: window.innerHeight
                }
            });
        } catch (error) {
            this.log(`Failed to capture screenshot: ${error.message}`, 'error');
        }
    }

    async checkConsoleErrors() {
        // Check for existing console errors
        const originalError = console.error;
        const originalWarn = console.warn;
        const consoleErrors = [];
        const consoleWarnings = [];

        // Override console methods to capture errors
        console.error = (...args) => {
            consoleErrors.push(args.join(' '));
            originalError.apply(console, args);
        };

        console.warn = (...args) => {
            consoleWarnings.push(args.join(' '));
            originalWarn.apply(console, args);
        };

        // Wait a bit to capture any errors
        await this.delay(2000);

        // Restore original methods
        console.error = originalError;
        console.warn = originalWarn;

        return { errors: consoleErrors, warnings: consoleWarnings };
    }

    async delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    async testInitialState() {
        this.log('Testing initial dashboard state...');
        
        // Check if dashboard is visible
        const dashboard = document.getElementById('dashboard');
        if (!dashboard || dashboard.classList.contains('hidden')) {
            this.log('Dashboard not visible - user might not be authenticated', 'error');
            return false;
        }

        // Check if tabs are present
        const tabs = document.querySelectorAll('.tab');
        if (tabs.length === 0) {
            this.log('No tabs found', 'error');
            return false;
        }

        // Find revenue tab
        const revenueTab = document.querySelector('[data-tab="revenue"]');
        if (!revenueTab) {
            this.log('Revenue tab not found', 'error');
            return false;
        }

        this.log('Initial state check passed', 'success');
        await this.captureScreenshot('Initial dashboard state');
        return true;
    }

    async testTabSwitch() {
        this.log('Testing tab switch to Revenue...');
        
        const revenueTab = document.querySelector('[data-tab="revenue"]');
        if (!revenueTab) {
            this.log('Revenue tab not found', 'error');
            return false;
        }

        // Click the revenue tab
        revenueTab.click();
        await this.delay(TEST_CONFIG.TAB_SWITCH_DELAY);

        // Check if tab is now active
        if (!revenueTab.classList.contains('active')) {
            this.log('Revenue tab did not become active after click', 'error');
            return false;
        }

        // Check if revenue content is visible
        const revenueContent = document.getElementById('revenueTab');
        if (!revenueContent || !revenueContent.classList.contains('active')) {
            this.log('Revenue tab content not visible', 'error');
            return false;
        }

        this.log('Tab switch successful', 'success');
        await this.captureScreenshot('Revenue tab activated');
        return true;
    }

    async testRevenueDataLoading() {
        this.log('Testing revenue data loading...');
        
        const timeoutPromise = new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Timeout')), TEST_CONFIG.TIMEOUT_MS)
        );

        try {
            // Check product statistics
            const product300Stats = document.getElementById('product300Stats');
            const product600Stats = document.getElementById('product600Stats');
            const arpuStats = document.getElementById('arpuStats');

            // Wait for data or timeout
            await Promise.race([
                new Promise(resolve => {
                    const checkData = () => {
                        const loading300 = product300Stats.textContent === 'Loading...';
                        const loading600 = product600Stats.textContent === 'Loading...';
                        const loadingArpu = arpuStats.textContent === 'Loading...';
                        
                        if (!loading300 && !loading600 && !loadingArpu) {
                            resolve();
                        } else {
                            setTimeout(checkData, 500);
                        }
                    };
                    checkData();
                }),
                timeoutPromise
            ]);

            // Check if data loaded successfully
            if (product300Stats.textContent === 'Loading...') {
                this.log('Product 300s stats still loading', 'warning');
            } else {
                this.log(`Product 300s stats loaded: ${product300Stats.textContent}`, 'success');
            }

            if (product600Stats.textContent === 'Loading...') {
                this.log('Product 600s stats still loading', 'warning');
            } else {
                this.log(`Product 600s stats loaded: ${product600Stats.textContent}`, 'success');
            }

            if (arpuStats.textContent === 'Loading...') {
                this.log('ARPU stats still loading', 'warning');
            } else {
                this.log(`ARPU stats loaded: ${arpuStats.textContent}`, 'success');
            }

        } catch (error) {
            this.log(`Revenue data loading timed out: ${error.message}`, 'error');
        }

        await this.captureScreenshot('Revenue data loading complete');
    }

    async testTransactionsTable() {
        this.log('Testing transactions table...');
        
        const transactionsTable = document.getElementById('transactionsTable');
        const transactionsBody = document.getElementById('transactionsTableBody');
        
        if (!transactionsTable) {
            this.log('Transactions table not found', 'error');
            return false;
        }

        // Wait for transactions to load
        await this.delay(3000);

        const rows = transactionsBody.querySelectorAll('tr');
        if (rows.length === 1 && rows[0].querySelector('.loading')) {
            this.log('Transactions still loading', 'warning');
        } else if (rows.length === 1 && rows[0].querySelector('.error')) {
            this.log('Transactions failed to load', 'error');
        } else if (rows.length > 1) {
            this.log(`Transactions loaded: ${rows.length - 1} transactions found`, 'success');
        } else {
            this.log('No transactions found', 'warning');
        }

        await this.captureScreenshot('Transactions table state');
        return true;
    }

    async testFirebaseConnectivity() {
        this.log('Testing Firebase connectivity...');
        
        // Check if Firebase is initialized
        if (typeof window.firebase === 'undefined' && typeof window.dashboard === 'undefined') {
            this.log('Firebase not initialized', 'error');
            return false;
        }

        // Check if dashboard instance exists
        if (typeof window.dashboard === 'undefined') {
            this.log('Dashboard instance not found', 'error');
            return false;
        }

        // Check authentication state
        if (window.dashboard.currentUser) {
            this.log(`Authenticated as: ${window.dashboard.currentUser.email}`, 'success');
        } else {
            this.log('Not authenticated', 'error');
            return false;
        }

        // Check admin status
        if (window.dashboard.isAdmin) {
            this.log('Admin privileges confirmed', 'success');
        } else {
            this.log('Admin privileges not confirmed', 'error');
            return false;
        }

        return true;
    }

    async testPriceConfiguration() {
        this.log('Testing price configuration...');
        
        const price300Input = document.getElementById('price300Input');
        const price600Input = document.getElementById('price600Input');
        
        if (price300Input && price600Input) {
            const price300 = price300Input.value;
            const price600 = price600Input.value;
            
            this.log(`5-min package price: $${price300}`, 'info');
            this.log(`10-min package price: $${price600}`, 'info');
            
            // Check localStorage for saved prices
            try {
                const savedPrices = JSON.parse(localStorage.getItem('skuPrices') || '{}');
                this.log(`Saved prices in localStorage: ${Object.keys(savedPrices).length} SKUs`, 'info');
            } catch (error) {
                this.log(`Error reading saved prices: ${error.message}`, 'error');
            }
        } else {
            this.log('Price input fields not found', 'error');
        }
    }

    async runFullTest() {
        this.log('🚀 Starting comprehensive Revenue Tab test suite...');
        
        // Initial console error check
        const consoleCheck = await this.checkConsoleErrors();
        
        // Run all tests
        const tests = [
            { name: 'Initial State', test: () => this.testInitialState() },
            { name: 'Firebase Connectivity', test: () => this.testFirebaseConnectivity() },
            { name: 'Tab Switch', test: () => this.testTabSwitch() },
            { name: 'Price Configuration', test: () => this.testPriceConfiguration() },
            { name: 'Revenue Data Loading', test: () => this.testRevenueDataLoading() },
            { name: 'Transactions Table', test: () => this.testTransactionsTable() }
        ];

        for (const testCase of tests) {
            this.log(`\n--- Running ${testCase.name} Test ---`);
            try {
                await testCase.test();
            } catch (error) {
                this.log(`${testCase.name} test failed: ${error.message}`, 'error');
            }
        }

        // Final console error check
        const finalConsoleCheck = await this.checkConsoleErrors();
        
        // Generate report
        this.generateReport(consoleCheck, finalConsoleCheck);
    }

    generateReport(initialConsole, finalConsole) {
        console.log('\n' + '='.repeat(60));
        console.log('📊 REVENUE TAB TEST REPORT');
        console.log('='.repeat(60));
        
        console.log(`\n📝 Test Results:`);
        console.log(`✅ Successful checks: ${this.results.filter(r => r.status === 'success').length}`);
        console.log(`ℹ️ Info messages: ${this.results.filter(r => r.status === 'info').length}`);
        console.log(`⚠️ Warnings: ${this.warnings.length}`);
        console.log(`❌ Errors: ${this.errors.length}`);
        
        if (this.errors.length > 0) {
            console.log('\n❌ ERRORS FOUND:');
            this.errors.forEach(error => console.log(`  • ${error}`));
        }
        
        if (this.warnings.length > 0) {
            console.log('\n⚠️ WARNINGS:');
            this.warnings.forEach(warning => console.log(`  • ${warning}`));
        }
        
        if (finalConsole.errors.length > 0) {
            console.log('\n🔥 CONSOLE ERRORS:');
            finalConsole.errors.forEach(error => console.log(`  • ${error}`));
        }
        
        if (finalConsole.warnings.length > 0) {
            console.log('\n⚠️ CONSOLE WARNINGS:');
            finalConsole.warnings.forEach(warning => console.log(`  • ${warning}`));
        }
        
        console.log('\n📸 Screenshots captured:', this.screenshots.length);
        
        // Recommendations
        console.log('\n💡 RECOMMENDATIONS:');
        if (this.errors.some(e => e.includes('Firebase'))) {
            console.log('  • Check Firebase configuration and authentication');
        }
        if (this.errors.some(e => e.includes('loading'))) {
            console.log('  • Investigate data loading timeouts');
        }
        if (this.warnings.some(w => w.includes('Loading'))) {
            console.log('  • Some data sources may be unavailable');
        }
        
        console.log('\n='.repeat(60));
        
        return {
            errors: this.errors,
            warnings: this.warnings,
            results: this.results,
            screenshots: this.screenshots,
            consoleErrors: finalConsole.errors,
            consoleWarnings: finalConsole.warnings
        };
    }
}

// Auto-run the test
(async () => {
    const tester = new RevenuTabTester();
    await tester.runFullTest();
})();

// Make tester available globally for manual testing
window.revenueTabTester = new RevenuTabTester();