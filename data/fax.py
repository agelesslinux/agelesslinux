#!/usr/bin/env python3
"""Fax Your Rep — PDF generation and Telnyx fax delivery.

Generates one-page fax documents with Ageless Linux branding and sends
them via the Telnyx Programmable Fax API.

Environment variables:
    TELNYX_API_KEY       - Telnyx V2 API key (required for sending)
    TELNYX_CONNECTION_ID - Programmable Fax Application connection ID
    TELNYX_FROM_NUMBER   - E.164 sending number, e.g. +13125790015
    FAX_BUDGET_CENTS     - Maximum total spend in cents (default: 500)

Usage:
    python fax.py preview "425 Market St, San Francisco, CA 94105"
    python fax.py send "425 Market St, San Francisco, CA 94105" --persona parent
    python fax.py status <fax-id>
    python fax.py budget
"""

import argparse
import datetime
import io
import json
import os
import re
import sys
from pathlib import Path

try:
    from reportlab.lib.pagesizes import LETTER
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.pdfgen import canvas
    from reportlab.platypus import Frame, Paragraph
except ImportError:
    print("reportlab required: pip install reportlab", file=sys.stderr)
    sys.exit(1)

# Import lookup module from same directory
sys.path.insert(0, str(Path(__file__).parent))
from lookup import LookupError, lookup_legislators

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

DATA_DIR = Path(__file__).parent
COST_LOG = DATA_DIR / "fax_costs.json"

TELNYX_API_BASE = "https://api.telnyx.com/v2"
COST_PER_PAGE_CENTS = 2  # ~$0.02/page conservative estimate (fax + SIP trunking)
DEFAULT_BUDGET_CENTS = 500  # $5.00

STATE_BILLS = {
    "CA": ("AB 1043", "Digital Age Assurance Act"),
    "CO": ("SB 26-051", "Digital Age Assurance Act"),
    "IL": ("SB 3977", "Digital Age Assurance Act"),
    "LA": ("HB 570", "Age Verification Act"),
    "NY": ("S8102A", "SAFE for Kids Act"),
    "TX": ("SB 2420", "Securing Children Online through Parental Empowerment Act"),
    "UT": ("SB 142", "Online Safety Amendments"),
}

# ---------------------------------------------------------------------------
# Campaign messages — one per CYOA persona
#
# All messages cite AB 1043 section numbers. The tool targets California
# legislators primarily (100% algorithmic fax coverage). Other states'
# bills derive from the same ICMEC model bill; state-specific messaging
# can be added in a future iteration.
# ---------------------------------------------------------------------------

MESSAGES = {
    "default": """\
You voted for Assembly Bill 1043. The tally: 76-0 in the Assembly, \
38-0 in the Senate. Not a single legislator voted no.

AB 1043 requires every operating system provider to collect the birth \
date of every child who uses a device and provide a real-time age \
bracket signal to every application. Section 1798.500(g) defines \
"operating system provider" as anyone who "develops, licenses, or \
controls the operating system software" on any general purpose \
computing device.

No exemption exists for open-source software, volunteer-maintained \
projects, non-commercial distributions, or educational tools.

Google, Meta, Snap, and OpenAI publicly endorsed this bill on \
September 9, 2025. They already comply at zero marginal cost. The \
600+ volunteer Linux distributions maintained by hobbyists and \
nonprofits cannot comply. A law that the largest companies in the \
world already meet, and that hundreds of small projects cannot, is \
not a child safety law. It is a compliance moat.

In September 2025, 70,000 government IDs were stolen from Discord's \
age verification vendor Persona. The breach lasted 58 hours. AB 1043 \
requires every operating system to build the next breach target.

Amend or repeal AB 1043 before the January 1, 2027 operative date.""",

    "parent": """\
I am a California parent. I already manage my children's screen time \
using the parental controls built into every device I own. Apple \
Screen Time, Google Family Link \u2014 these tools work. I chose \
them. I configured them. I decide what my children can access.

AB 1043 replaces my judgment with a state mandate. Section \
1798.501(a)(1) requires every operating system to collect my child's \
birth date at account setup. This is not optional. This is not at my \
discretion. The state has decided that my parenting is insufficient.

My child's birth date will now be stored by every operating system \
they touch. In September 2025, 70,000 government IDs were stolen \
from Discord's age verification vendor. You voted to create the next \
breach target \u2014 with my child's data.

The only thing my child will learn from this law is how to lie to a \
computer. That is not child safety. That is Prohibition \u2014 not \
the policy, but the pedagogy.

I am the parent. Not Sacramento.

Amend AB 1043 to make age collection opt-in at the parent's \
discretion, or repeal it entirely, before January 1, 2027.""",

    "developer": """\
I maintain open-source software used by thousands of people. AB 1043 \
says I am an "operating system provider."

Section 1798.500(g) defines that term as anyone who "develops, \
licenses, or controls the operating system software" on any general \
purpose computing device. No exemption for open source. No exemption \
for volunteers. No exemption for non-commercial projects.

A calculator firmware developer \u2014 a calculator \u2014 chose to \
geo-block California rather than face $7,500 per child in fines \
under Section 1798.503(a). Compliance costs start at $20,000 for \
small businesses. Most open-source projects have zero revenue.

Google, Meta, Snap, and OpenAI publicly endorsed this bill. They \
already collect age data. They already comply at zero marginal cost. \
The 600+ volunteer Linux distributions cannot. A law that the \
largest companies in the world already meet, and that hundreds of \
small projects cannot, is not a child safety law. It is a compliance \
moat.

The companies that benefit from OS-level age verification funded the \
organization that advocated for it. Common Sense Media receives \
funding from Chan Zuckerberg Initiative, Bezos Foundation, and Gates \
Foundation.

Exempt non-commercial and open-source software from AB 1043, or \
repeal it entirely, before January 1, 2027.""",

    "student": """\
I am a California student. I taught myself to code on a Linux \
computer. Under AB 1043, the operating system I used to learn would \
need to collect my birth date and tell every application I open that \
I am a minor.

Section 1798.500(i) defines "user" as "a child that is the primary \
user of the device." Adults are "account holders." I am not a person \
in this law. I am a category to be regulated.

Under Section 1798.501(b)(2)(A), every developer who receives the \
age signal has "deemed actual knowledge" of my age bracket. If I am \
honest about being under 18, applications will restrict what I can \
access. If I lie and say I am 21, everything works normally. You are \
teaching me that honesty is punished and that legal compliance \
prompts are obstacles to bypass.

I started programming when I was 12. The open-source tools I learned \
with would be illegal to distribute in California without a real-time \
age verification API that their volunteer maintainers cannot build.

Do not make it harder for students to learn. Amend or repeal AB 1043 \
before January 1, 2027.""",

    "privacy": """\
In September 2025, 70,000 government ID photos were stolen from \
Discord's age verification vendor Persona. The breach lasted 58 \
hours. Criminal group Scattered LAPSUS$ Hunters claimed 1.5TB of \
data from 5.5 million users.

That is what age verification produces. Not safety. A target.

AB 1043 requires every operating system to collect birth dates under \
Section 1798.501(a)(1) and send age signals to every application \
under Section 1798.501(a)(2). This creates surveillance \
infrastructure at the OS level. Today it is self-declaration. \
Industry analysts describe self-declaration as "getting the door \
open." Tomorrow it is biometric verification.

Cory Doctorow: "If a system can determine someone's age, it can \
determine who they are." Professor Steven Bellovin at Columbia \
confirmed this in peer-reviewed research. There is no technical \
architecture that separates age from identity.

15 million Americans lack driver's licenses. 43% of transgender \
Americans lack identity documents matching their actual identity. \
18% of Black adults lack licenses versus 5% of white adults. Age \
verification is not neutral.

Do not build surveillance infrastructure that will be breached, \
repurposed, or weaponized. Repeal AB 1043.""",
}


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def normalize_fax_number(raw: str) -> str:
    """Convert fax number to E.164 format (+1XXXXXXXXXX)."""
    digits = re.sub(r"\D", "", raw)
    if len(digits) == 10:
        return f"+1{digits}"
    if len(digits) == 11 and digits.startswith("1"):
        return f"+{digits}"
    raise ValueError(f"Cannot normalize fax number: {raw!r}")


def _xml_escape(text: str) -> str:
    """Escape text for reportlab Paragraph XML markup."""
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _legislator_state(legislator: dict) -> str:
    """Extract state abbreviation from legislator district field."""
    district = legislator.get("district", "")
    if len(district) >= 2 and district[:2].isalpha():
        return district[:2].upper()
    return "CA"


# ---------------------------------------------------------------------------
# PDF generation
# ---------------------------------------------------------------------------

def generate_fax_pdf(legislator: dict, persona: str = "default") -> bytes:
    """Generate a one-page fax PDF for a legislator. Returns PDF bytes."""
    if persona not in MESSAGES:
        raise ValueError(
            f"Unknown persona: {persona!r} (available: {', '.join(MESSAGES)})"
        )

    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=LETTER)
    width, height = LETTER  # 612 x 792 points

    # Metadata
    state = _legislator_state(legislator)
    bill_num, bill_name = STATE_BILLS.get(
        state, ("AB 1043", "Digital Age Assurance Act")
    )
    c.setTitle(f"Fax to {legislator['name']} \u2014 {bill_num}")
    c.setAuthor("Ageless Linux \u2014 agelesslinux.org")
    c.setSubject(f"{bill_num} \u2014 {bill_name}")
    c.setCreator("agelesslinux.org/fax")

    margin = 54  # 0.75 inch
    usable_w = width - 2 * margin
    y = height - margin

    # --- Header ---
    c.setFont("Helvetica-Bold", 18)
    c.drawString(margin, y, "AGELESS LINUX")
    y -= 14
    c.setFont("Helvetica", 8)
    c.drawString(
        margin, y,
        "agelesslinux.org  \u2022  FFwF Robotics LLC  \u2022  Unlicense",
    )
    y -= 10
    c.setLineWidth(1.5)
    c.line(margin, y, width - margin, y)
    y -= 20

    # --- Address block ---
    label_x = margin
    value_x = margin + 38

    c.setFont("Helvetica-Bold", 10)
    c.drawString(label_x, y, "TO:")
    c.setFont("Helvetica", 10)
    c.drawString(value_x, y, legislator["name"])
    y -= 14
    c.drawString(
        value_x, y,
        f"{legislator['office']}  \u2014  {legislator['district']}",
    )
    y -= 18

    c.setFont("Helvetica-Bold", 10)
    c.drawString(label_x, y, "RE:")
    c.setFont("Helvetica", 10)
    c.drawString(value_x, y, f"{bill_num}  \u2014  {bill_name}")
    y -= 18

    c.setFont("Helvetica-Bold", 10)
    c.drawString(label_x, y, "DATE:")
    c.setFont("Helvetica", 10)
    c.drawString(value_x, y, datetime.date.today().strftime("%B %d, %Y"))
    y -= 12

    c.setLineWidth(0.5)
    c.line(margin, y, width - margin, y)
    y -= 14

    # --- Body text (using Frame + Paragraph for word wrapping) ---
    footer_top = margin + 50
    body_height = y - footer_top

    body_style = ParagraphStyle(
        "body",
        fontName="Helvetica",
        fontSize=10,
        leading=13.5,
        spaceAfter=7,
    )
    closing_style = ParagraphStyle(
        "closing",
        fontName="Helvetica-Oblique",
        fontSize=9,
        leading=12,
        spaceBefore=10,
    )

    story = []
    for para in MESSAGES[persona].split("\n\n"):
        escaped = _xml_escape(para.replace("\n", " "))
        story.append(Paragraph(escaped, body_style))

    story.append(
        Paragraph(
            _xml_escape("Sent by a constituent via agelesslinux.org."),
            closing_style,
        )
    )

    frame = Frame(
        margin, footer_top, usable_w, body_height,
        showBoundary=0,
        topPadding=0, bottomPadding=0, leftPadding=0, rightPadding=0,
    )
    remaining = frame.addFromList(story, c)
    if remaining:
        print("WARNING: body text overflowed one page", file=sys.stderr)

    # --- Footer ---
    footer_rule_y = margin + 42
    c.setLineWidth(0.5)
    c.line(margin, footer_rule_y, width - margin, footer_rule_y)
    c.setFont("Helvetica-Oblique", 9)
    c.drawString(margin, footer_rule_y - 14, "No age verification required to send a fax.")
    c.setFont("Helvetica", 8)
    c.drawRightString(width - margin, footer_rule_y - 14, "agelesslinux.org")

    c.save()
    return buf.getvalue()


# ---------------------------------------------------------------------------
# Cost tracking
# ---------------------------------------------------------------------------

def _load_costs() -> list:
    if COST_LOG.exists():
        with open(COST_LOG) as f:
            return json.load(f)
    return []


def _save_costs(costs: list):
    tmp = COST_LOG.with_suffix(".tmp")
    with open(tmp, "w") as f:
        json.dump(costs, f, indent=2)
    tmp.rename(COST_LOG)


def _total_spent_cents() -> int:
    return sum(entry.get("cost_cents", 0) for entry in _load_costs())


def log_cost(fax_id: str, to_number: str, legislator_name: str, pages: int = 1):
    """Append a fax send to the cost log."""
    costs = _load_costs()
    costs.append({
        "fax_id": fax_id,
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        "to": to_number,
        "legislator": legislator_name,
        "pages": pages,
        "cost_cents": pages * COST_PER_PAGE_CENTS,
    })
    _save_costs(costs)


def budget_summary() -> str:
    """Return a human-readable spending summary."""
    costs = _load_costs()
    total_cents = sum(e.get("cost_cents", 0) for e in costs)
    budget_cents = int(os.environ.get("FAX_BUDGET_CENTS", DEFAULT_BUDGET_CENTS))
    lines = [
        f"Budget:    ${budget_cents / 100:.2f}",
        f"Spent:     ${total_cents / 100:.2f} ({len(costs)} fax{'es' if len(costs) != 1 else ''})",
        f"Remaining: ${(budget_cents - total_cents) / 100:.2f}",
    ]
    if costs:
        lines.append("")
        lines.append("Recent:")
        for entry in costs[-10:]:
            lines.append(
                f"  {entry['timestamp'][:10]}  {entry['legislator']:<30s}  "
                f"{entry['to']:<15s}  ${entry['cost_cents'] / 100:.2f}  "
                f"{entry.get('fax_id', 'N/A')[:12]}"
            )
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Telnyx API
# ---------------------------------------------------------------------------

def _get_telnyx_config() -> tuple[str, str, str]:
    """Read Telnyx configuration from environment variables."""
    api_key = os.environ.get("TELNYX_API_KEY")
    connection_id = os.environ.get("TELNYX_CONNECTION_ID")
    from_number = os.environ.get("TELNYX_FROM_NUMBER")

    missing = []
    if not api_key:
        missing.append("TELNYX_API_KEY")
    if not connection_id:
        missing.append("TELNYX_CONNECTION_ID")
    if not from_number:
        missing.append("TELNYX_FROM_NUMBER")

    if missing:
        raise RuntimeError(
            f"Missing environment variables: {', '.join(missing)}\n"
            "Set these before sending faxes. See module docstring for details."
        )

    return api_key, connection_id, from_number


def send_fax(to_number: str, pdf_bytes: bytes) -> dict:
    """Send a fax via Telnyx Programmable Fax API.

    Uses multipart upload to send the PDF directly.
    Returns dict with 'fax_id' and 'status'.
    """
    try:
        import requests
    except ImportError:
        raise RuntimeError("requests required for sending: pip install requests")

    api_key, connection_id, from_number = _get_telnyx_config()

    # Enforce budget ceiling
    budget_cents = int(os.environ.get("FAX_BUDGET_CENTS", DEFAULT_BUDGET_CENTS))
    spent = _total_spent_cents()
    if spent + COST_PER_PAGE_CENTS > budget_cents:
        raise RuntimeError(
            f"Budget ceiling reached: ${spent / 100:.2f} spent of "
            f"${budget_cents / 100:.2f} limit. "
            f"Set FAX_BUDGET_CENTS to increase."
        )

    resp = requests.post(
        f"{TELNYX_API_BASE}/faxes",
        headers={"Authorization": f"Bearer {api_key}"},
        data={
            "connection_id": connection_id,
            "from": from_number,
            "to": to_number,
            "quality": "high",
        },
        files={
            "contents": ("fax.pdf", pdf_bytes, "application/pdf"),
        },
        timeout=30,
    )

    if resp.status_code not in (200, 201, 202):
        raise RuntimeError(f"Telnyx API error {resp.status_code}: {resp.text}")

    fax_data = resp.json().get("data", {})
    return {
        "fax_id": fax_data.get("id", "unknown"),
        "status": fax_data.get("status", "unknown"),
    }


def get_fax_status(fax_id: str) -> dict:
    """Poll Telnyx for the current status of a sent fax."""
    try:
        import requests
    except ImportError:
        raise RuntimeError("requests required: pip install requests")

    api_key = os.environ.get("TELNYX_API_KEY")
    if not api_key:
        raise RuntimeError("TELNYX_API_KEY not set")

    resp = requests.get(
        f"{TELNYX_API_BASE}/faxes/{fax_id}",
        headers={"Authorization": f"Bearer {api_key}"},
        timeout=15,
    )

    if resp.status_code != 200:
        raise RuntimeError(f"Telnyx API error {resp.status_code}: {resp.text}")

    return resp.json().get("data", {})


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _print_legislators(legislators: list[dict]):
    """Print legislator list with fax availability."""
    for i, leg in enumerate(legislators):
        fax_str = ", ".join(leg["fax"]) if leg.get("fax") else "none on file"
        marker = "\u2713" if leg.get("fax") else "\u2717"
        print(f"  [{i}] {marker} {leg['name']}")
        print(f"      {leg['office']} \u2014 {leg['district']} ({leg['party']})")
        print(f"      Fax: {fax_str}")


def main():
    parser = argparse.ArgumentParser(
        description="Fax Your Rep \u2014 generate and send faxes to legislators",
        epilog="Set TELNYX_API_KEY, TELNYX_CONNECTION_ID, TELNYX_FROM_NUMBER to send.",
    )
    sub = parser.add_subparsers(dest="command")

    p_preview = sub.add_parser("preview", help="Generate fax PDFs for review")
    p_preview.add_argument("address", help="US street address")
    p_preview.add_argument(
        "--persona", default="default", choices=MESSAGES.keys(),
        help="Campaign message persona (default: cross-cutting)",
    )
    p_preview.add_argument(
        "--output-dir", default=".",
        help="Directory for output PDFs (default: current directory)",
    )

    p_send = sub.add_parser("send", help="Generate and send faxes")
    p_send.add_argument("address", help="US street address")
    p_send.add_argument(
        "--persona", default="default", choices=MESSAGES.keys(),
    )
    p_send.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be sent without sending",
    )
    p_send.add_argument(
        "--index", type=int,
        help="Send to a specific legislator by index (from preview output)",
    )

    p_status = sub.add_parser("status", help="Check fax delivery status")
    p_status.add_argument("fax_id", help="Telnyx fax ID")

    sub.add_parser("budget", help="Show spending summary")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    if args.command == "budget":
        print(budget_summary())
        return

    if args.command == "status":
        try:
            data = get_fax_status(args.fax_id)
        except RuntimeError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            sys.exit(1)
        print(f"Fax {args.fax_id}:")
        print(f"  Status: {data.get('status', 'unknown')}")
        print(f"  To:     {data.get('to', 'unknown')}")
        print(f"  From:   {data.get('from_', data.get('from', 'unknown'))}")
        if data.get("page_count"):
            print(f"  Pages:  {data['page_count']}")
        if data.get("failure_reason"):
            print(f"  Failure: {data['failure_reason']}")
        return

    # preview and send both need address lookup
    try:
        result = lookup_legislators(args.address)
    except LookupError as exc:
        print(f"Lookup error: {exc}", file=sys.stderr)
        sys.exit(1)

    legislators = result["legislators"]
    faxable = [(i, leg) for i, leg in enumerate(legislators) if leg.get("fax")]

    print(f"Address: {result['address']}")
    d = result["districts"]
    print(
        f"Districts: CD-{d['congressional']:02d}, "
        f"SD-{d['state_senate']:02d}, "
        f"AD-{d['state_assembly']:02d} ({d['state']})"
    )
    print(f"Legislators found: {len(legislators)} ({len(faxable)} with fax)\n")

    _print_legislators(legislators)
    print()

    if not faxable:
        print("No fax-reachable legislators for this address.", file=sys.stderr)
        sys.exit(1)

    if args.command == "preview":
        out_dir = Path(args.output_dir)
        out_dir.mkdir(parents=True, exist_ok=True)

        print(f"Generating PDFs (persona: {args.persona}):\n")
        for i, leg in faxable:
            pdf_bytes = generate_fax_pdf(leg, args.persona)
            safe_name = re.sub(r"[^\w\-]", "_", leg["name"].lower())
            filename = out_dir / f"fax_{safe_name}.pdf"
            with open(filename, "wb") as f:
                f.write(pdf_bytes)
            print(f"  [{i}] {leg['name']} \u2192 {filename} ({len(pdf_bytes)} bytes)")

    elif args.command == "send":
        if args.index is not None:
            targets = [(i, leg) for i, leg in faxable if i == args.index]
            if not targets:
                print(
                    f"Error: index {args.index} not found or has no fax number",
                    file=sys.stderr,
                )
                sys.exit(1)
        else:
            targets = faxable

        label = "[DRY RUN] " if args.dry_run else ""
        print(f"{label}Sending to {len(targets)} legislator(s) (persona: {args.persona}):\n")

        for i, leg in targets:
            fax_number = leg["fax"][0]  # first = preferred (DC office or capitol)
            try:
                e164 = normalize_fax_number(fax_number)
            except ValueError as exc:
                print(f"  [{i}] {leg['name']} \u2014 SKIPPED: {exc}")
                continue

            print(f"  [{i}] {leg['name']}")
            print(f"      Fax: {fax_number} \u2192 {e164}")

            if args.dry_run:
                pdf_bytes = generate_fax_pdf(leg, args.persona)
                print(f"      PDF: {len(pdf_bytes)} bytes")
                print(f"      Est. cost: ${COST_PER_PAGE_CENTS / 100:.2f}")
                print()
                continue

            try:
                pdf_bytes = generate_fax_pdf(leg, args.persona)
                send_result = send_fax(e164, pdf_bytes)
                fax_id = send_result["fax_id"]
                log_cost(fax_id, e164, leg["name"])
                print(f"      Sent: {send_result['status']} (ID: {fax_id})")
            except RuntimeError as exc:
                print(f"      FAILED: {exc}")
            print()

        if not args.dry_run:
            print(budget_summary())


if __name__ == "__main__":
    main()
