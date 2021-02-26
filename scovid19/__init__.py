from flask import Flask, render_template, request

import os, logging
from scovid19.lib.Vaccine import Vaccine
from scovid19.lib.Infections import Infections
from scovid19.lib.Decorators import page, endpoint
from dotenv import load_dotenv

# Load .env
load_dotenv()
project_root = os.environ["PROJECT_ROOT"]

app = Flask(__name__, static_url_path="")


def get_logger(name, file_path, level=logging.INFO):
	logger = logging.getLogger(name)
	formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] [%(name)s]: %(message)s")
	handler = logging.FileHandler(file_path)
	handler.setFormatter(formatter)
	logger.addHandler(handler)
	return logger


# Set up logger
app_logger = get_logger("app", f"{project_root}/logs/app.log")

infections = Infections()
vaccines = Vaccine()

# Page routes
@app.route("/")
@page
def index():
	return render_template(
		"infections.html.j2",
		summary=infections.summary(),
		last_updated=infections.last_updated(format="%d %B %Y"),
		tab="overview",
	)


@app.route("/vaccine")
@page
def vaccine():
	return render_template(
		"vaccine.html.j2",
		tab="vaccine",
		weekly=vaccines.vaccines_weekly(),
		percentage=vaccines.percentage_vaccinated(),
		last_updated=infections.last_updated(format="%d %B %Y"),
	)


#== API routes ==#

# Misc
@app.route("/api/ping")
def ping():
	return "Ok"

# Infections
@app.route("/api/infections/trend")
@endpoint
def trend():
	return infections.trend(request.args)

@app.route("/api/infections/breakdown")
@endpoint
def breakdown():
	return infections.breakdown()

@app.route("/api/infections/locations")
@endpoint
def locations():
	full = request.args.get('full', False)
	return infections.locations(full)

# Vaccines
@app.route("/api/vaccines/breakdown")
@endpoint
def percentage_vaccinated():
	return vaccines.percentage_vaccinated()

@app.route("/api/vaccines/council")
@endpoint
def council_breakdown():
	return vaccines.council_breakdown()

@app.route("/api/vaccines/trend")
@endpoint
def vaccine_trend():
	return vaccines.vaccine_trend()

@app.route("/api/prevalence")
@endpoint
def prevalence():
	limit = int(request.args["limit"]) if "limit" in request.args else -1
	return infections.prevalence()[0:limit]


if __name__ == "__main__":
	app.run()
