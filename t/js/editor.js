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

  page.on('console', msg => console.log( '# console.log: ' + msg.text() ))
  page.on('pageerror', exception => {
    console.log(`# Uncaught exception: ${exception.stack}`);
  });

  await page.goto(url + '/new_editor');
  const body = await page.innerHTML('#tab-pane .active');

  const schemaList = await page.$$('#schema-menu li');
  t.is( schemaList.length, 1, 'one schema in list' );
  t.is( await schemaList[0].getAttribute('data-schema'), 'user', 'first schema is "user"' );

  await t.test( 'list users', async t => {
    await page.click('#schema-menu li[data-schema=user]');
    const list = page.$( 'schema-list' );
    t.ok( list, 'schema-list element exists' );
    // XXX: Test schema list
  });
 
  await t.test( 'create new user form', async t => {
    await page.click('button[data-create]');

    const usernameInput = await page.$( '[name=username] input' );
    t.ok( usernameInput, 'username input exists' );
    t.is(
      await usernameInput.getAttribute( 'type' ), 'text',
      'username input type is correct',
    );
    t.is(
      await usernameInput.getAttribute( 'minlength' ), '6',
      'username input minlength is correct',
    );
    t.is(
      await usernameInput.getAttribute( 'maxlength' ), '100',
      'username input maxlength is correct',
    );
    t.is(
      await usernameInput.getAttribute( 'pattern' ), '^\\w+$',
      'username input pattern is correct',
    );

    const ageInput = await page.$( '[name=age] input' );
    t.ok( ageInput, 'age input exists' );
    t.is(
      await ageInput.getAttribute( 'type' ), 'number',
      'age input type is correct',
    );
    t.is(
      await ageInput.getAttribute( 'inputmode' ), 'numeric',
      'age input inputmode is correct',
    );
    t.is(
      await ageInput.getAttribute( 'pattern' ), '[0-9]*',
      'age input pattern is correct',
    );
    t.is(
      await ageInput.getAttribute( 'min' ), '13',
      'age input min is correct',
    );
    t.is(
      await ageInput.getAttribute( 'max' ), '120',
      'age input max is correct',
    );

    const emailInput = await page.$( '[name=email] input' );
    t.ok( emailInput, 'email input exists' );
    t.is(
      await emailInput.getAttribute( 'type' ), 'email',
      'email input type is correct',
    );

    const urlInput = await page.$( '[name=url] input' );
    t.ok( urlInput, 'url input exists' );
    t.is(
      await urlInput.getAttribute( 'type' ), 'url',
      'url input type is correct',
    );

    const telInput = await page.$( '[name=phone] input' );
    t.ok( telInput, 'phone input exists' );
    t.is(
      await telInput.getAttribute( 'type' ), 'tel',
      'phone input type is correct',
    );

    const discountInput = await page.$( '[name=discount] input' );
    t.ok( discountInput, 'discount input exists' );
    t.is(
      await discountInput.getAttribute( 'type' ), 'number',
      'discount input type is correct',
    );
    t.is(
      await discountInput.getAttribute( 'inputMode' ), 'decimal',
      'discount input inputMode is correct',
    );

    await page.click('#input-age-label');
    t.ok( await page.$( '#input-age input:focus' ), 'input gets focus when label is clicked' );
    await page.keyboard.press( 'Tab' );
    t.ok( await page.$( '#input-discount input:focus' ), 'next input gets focus when Tab is pressed' );

    const usernameLabel = await page.$( '[name=username] label' );
    t.is(
      await usernameLabel.innerText(), 'Username',
      'label uses "title" from schema',
    );
    const phoneLabel = await page.$( '[name=phone] label' );
    t.is(
      await phoneLabel.innerText(), 'phone',
      'label falls back to property name',
    );
    const usernameDesc = await page.$( '[name=username] small' );
    t.is(
      await usernameDesc.innerText(),
      "The user's login name",
      'description uses "description" from schema',
    );

    await t.test( 'submit create form (error)', async t => {
      await page.fill( '[name=username] input', 'bender' );
      await page.fill( '[name=age] input', '4' );
      await page.fill( '[name=email] input', 'bender@example.com' );
      await page.fill( '[name=phone] input', '(132) 555-0123' );
      await page.click( '[name=submit]' );
      // page.fill( 'selector', 'text' );
      // page.selectOption( 'selector', 'value' );
      // page.setChecked( 'selector', true|false );
      // page.setInputFiles( 'selector', {name: string, mimeType: string, buffer: Buffer } );
      let ul = await page.waitForSelector('ul.errors');
      t.ok( ul, 'errors ul exists' );
      let errors = await ul.$$('li');
      t.is( errors.length, 1, 'one error' ) || t.diag( await errors.textContent() );
      t.is( await errors[0].textContent(), '/age: 4 < minimum(13)', 'error message is correct' );
    });

    await t.test( 'submit create form (success)', async t => {
      await page.fill( '[name=username] input', 'bender' );
      await page.fill( '[name=age] input', '18' );
      await page.fill( '[name=email] input', 'bender@example.com' );
      await page.fill( '[name=phone] input', '(132) 555-0123' );
      await page.click( '[name=submit]' );
      // XXX: Wait for "saved" message
      // XXX: Tab should close
      // XXX: User list should be showing now
      // XXX: New user should appear in list
      const res = await context.request.get( url + '/user/bender' );
      t.ok( res.ok(), 'can get new item from API' );
      const item = await res.json();
      t.is( item.age, '18', 'age is correct' );
      t.is( item.email, 'bender@example.com', 'email is correct' );
      t.is( item.url, null, 'url is correct' );
    });
  });

  await context.close();
  await browser.close();
  await server.close();
});
