from playwright.sync_api import sync_playwright

CONFIG_FILE = "dataHMI.txt"  # Must be in same folder as this script

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()

    # 1. Go to login page
    page.goto("http://localhost:8080/ScadaBR")

    # 2. Log in
    page.fill('input[name="username"]', 'admin')
    page.fill('input[name="password"]', 'admin')
    page.click('input[type="submit"]')

    # 3. Wait for main dashboard to load
    page.wait_for_selector("text=Watch List")

    # 4. Navigate directly to the import page
    page.goto("http://localhost:8080/ScadaBR/emport.shtm")

    # 5. Wait for the correct textarea to be present
    page.wait_for_selector("#emportData")

    # 6. Read the config file content
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        config_text = f.read()

    # 7. Inject the text into the textarea using JS
    page.evaluate("(data) => document.getElementById('emportData').value = data", config_text)

    # 8. Click the Import button
    page.click("input[value='Import']")


    browser.close()
