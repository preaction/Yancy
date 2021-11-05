#!/usr/bin/env node
const t = require('tap');
const starter = require('@mojolicious/server-starter');
const { chromium } = require('playwright');

t.test('Test the Hello World app', async t => {
  const server = await starter.newServer();
  await server.launch('perl', ['t/js/app.pl', 'daemon', '-l', 'http://*?fd=3']);
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();
  const url = server.url();

  page.on('console', msg => console.log(msg.text()))

  await page.goto(url + '/new_editor');
  const body = await page.innerHTML('#tab-pane .active');
  console.log(body);

  const schemaList = await page.innerHTML('#schema-list li');
  console.log( schemaList );

  await page.click('#schema-list li[data-schema=user]')

  await context.close();
  await browser.close();
  await server.close();
});
