const path = require('path');

const mode = process.env.NODE_ENV || 'development';
const prod = mode === 'production';

module.exports = {
	entry: {
		bundle: [ './src/frontend/main.js' ]
	},
	resolve: {
		alias: {
			svelte: path.resolve('node_modules', 'svelte')
		},
		extensions: [ '.mjs', '.js', '.svelte' ],
		mainFields: [ 'svelte', 'browser', 'module', 'main' ]
	},
	output: {
		path: __dirname + '/public',
		filename: prod ? '[name]-[chunkhash].js' : '[name].js',
		chunkFilename: '[name].[id].js'
	},
	module: {
		rules: [
			{
				test: /\.svelte$/,
				use: {
					loader: 'svelte-loader',
					options: {
						emitCss: true,
						hotReload: true
					}
				}
			},
			{
				test: /\.css$/,
				use: [
					'style-loader',
					'css-loader'
				]
			}
		]
	},
	mode,
	plugins: [],
	devtool: prod ? false: 'source-map'
};

