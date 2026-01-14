from playwright.sync_api import sync_playwright

openplc_ports = [28080, 38080, 48080]

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()

    for port in openplc_ports:
        url = f"http://localhost:{port}/login"
        print(f"[+] Connecting to OpenPLC on {url}...")

        page.goto(url)

        print("[+] Filling in login form...")
        page.fill('input[placeholder="username"]', 'openplc')
        page.fill('input[placeholder="password"]', 'openplc')

        print("[+] Submitting login form...")
        page.evaluate("document.querySelector('form').submit()")
        page.wait_for_selector("text=Dashboard", timeout=10000)
        

        print("[+] Navigating to Hardware page...")
        page.click("text=Hardware")
        page.wait_for_selector("text=OpenPLC Hardware Layer")
     

        print("[+] Clicking Save changes...")
        page.click("input[type='submit'][value='Save changes']")
        page.wait_for_timeout(2000)
        

        print(f"[+] {port} complete.\n")

    browser.close()
    print("[+] All OpenPLC instances processed.")
