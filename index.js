const shell = require('shelljs')
const fail = require('gulp-fail')
const path = require('path')
const fs = require('fs')
const runSequenceImport = require('run-sequence')


const GROUP_FILE = '.group'
const DEPLOYMENT_FILE = '.deployment'
const PREFIX_FILE = '.prefix'
const LOCATION_FILE = '.location'
const PRODUCT_FILE = '.product'

const MAIN_TEMPLATE_NAME = 'mainTemplate.json'
const CREATE_UI_DEFINITION_NAME = 'createUiDefinition.json'

const product = function () {
    return shell.test('-f', PRODUCT_FILE) ? shell.cat(PRODUCT_FILE).trim() : "jira"
}

const GROUP_NAME = product() + '-dc-'

const location = function () {
	return shell.test('-e', LOCATION_FILE) ? shell.cat(LOCATION_FILE).trim() : 'AustraliaEast'
}

const prefix = function () {
	return shell.test('-e', PREFIX_FILE) ? shell.cat(PREFIX_FILE).trim() : ''
}

const current = function () {
	return shell.test('-f', GROUP_FILE) ? parseInt(shell.cat(GROUP_FILE)) : 0
}

const next = function () {
	return current() + 1
}

const nextDeployment = function () {
	return currentDeployment() + 1
}

const currentDeployment = function () {
	return shell.test('-f', DEPLOYMENT_FILE) ? parseInt(shell.cat(DEPLOYMENT_FILE)) : 0
}

async function createDeploymentTask(deployment = getDeploymentPath(), params = getDeploymentParametersPath()) {
	const group = current()
	const deploymentNumber = currentDeployment()
	if (group) {
		return new Promise((resolve, reject) => shell.exec(`az group deployment create -n "deployment-${deploymentNumber}" -g ${prefix()}${GROUP_NAME}${group} --template-file ${deployment} --parameters @${params}`, (code, stdout, stderr) => {
			if (code !== 0) {
				reject(new Error(stdout + stderr))
			}
			resolve(stdout)
		})).then(result => {
			const createDeployResult = JSON.parse(result)
			fs.writeFileSync('.createDeployResult', result)
			const nextDeployment = nextDeployment()
			shell.echo(nextDeployment).to(DEPLOYMENT_FILE)
			return createDeployResult
		})
	}
	throw new Error('No group')
}

function getDeploymentParametersPath() {
	return __dirname + `/${product()}/azuredeploy.parameters.json`
}

function getDeploymentPath() {
	return __dirname + `/${product()}/azuredeploy.json`
}

function applyTasks (gulp) {
	const runSequence = runSequenceImport.use(gulp)

	gulp.task('check-az-cli', () => {
		if (!shell.which('az')) {
			fail('Unable to find Azure CLI')
		}
	})

	gulp.task('check-zip-cli', () => {
		if (!shell.which('zip')) {
			fail('Unable to find ZIP utility')
		}
	})

	gulp.task('drop-existing-group', ['check-az-cli'], () => {
		const group = current()
		if (group) {
			const {code, stdout, stderr} = shell.exec(`az group delete --name ${prefix()}${GROUP_NAME}${group} --no-wait --yes`)
			if (code) {
				fail(stderr)
			}
		}
	})

	gulp.task('create-next-group', ['check-az-cli', 'drop-existing-group'], () => {
		const group = next()
		if (group) {
			const {code, stdout, stderr} = shell.exec(`az group create -n ${prefix()}${GROUP_NAME}${group} -l ${location()}`)
			if (code) {
				fail(stderr)
			}
		} else {
			fail('No group')
		}
	})


	gulp.task('create-deployment', ['check-az-cli'], () => createDeploymentTask().catch(e => fail(e)))
	gulp.task('update-group', ['create-next-group'], () => {
		const group = next()
		shell.echo(group).to(GROUP_FILE)
	})
	gulp.task('clean-group', () => {
		shell.rm(GROUP_FILE)
	})

	gulp.task('start', () => runSequence('update-group', 'create-deployment'))
	gulp.task('stop', ['drop-existing-group'])

	gulp.task('publish-jira', () => {
		const source = __dirname + '/jira'
		const target = 'target'
		const jira = path.resolve(target, 'jira')

		shell.mkdir('-p', jira)
		shell.cp(path.resolve(source, 'azuredeploy.json'), path.resolve(jira, MAIN_TEMPLATE_NAME))
		shell.cp(path.resolve(source, 'createUIDefinition.json'), path.resolve(jira, CREATE_UI_DEFINITION_NAME))
		shell.cp(path.resolve(source, 'scripts', '*'), jira)
		shell.cp(path.resolve(source, 'templates', '*'), jira)
		shell.exec([
			'zip',
			'-r',
			'--junk-paths',
			path.resolve(target, 'jira.zip'),
			jira
		].join(' '))
	})

	gulp.task('publish-confluence', () => {
		const source = __dirname + '/confluence'
		const target = __dirname + '/target'
		const resources = ['scripts', 'templates', 'libs']
		const confluence = path.resolve(target, 'confluence')
		resources.forEach(dir => {
			shell.mkdir('-p', path.resolve(confluence, dir))
		})
		shell.cp(path.resolve(source, 'azuredeploy.json'), path.resolve(confluence, MAIN_TEMPLATE_NAME))
		shell.cp(path.resolve(source, 'createUIDefinition.json'), path.resolve(confluence, CREATE_UI_DEFINITION_NAME))
		resources.forEach(dir => {
			shell.cp(path.resolve(source, dir, '*'), path.resolve(confluence, dir))
		})
		shell.pushd(confluence)
		shell.exec([
			'zip',
			'-r',
			'confluence.zip',
			'*',
			'-9'
		].join(' '))
		shell.mv(path.resolve(confluence, 'confluence.zip'), path.resolve(target, 'confluence.zip'))
		shell.popd()
	})

	gulp.task('publish', () => runSequence('check-zip-cli', `publish-${product()}`))
}

module.exports = {applyTasks, createDeploymentTask, getDeploymentParametersPath, getDeploymentPath}

