all:
	python manage.py runserver

db:
	python manage.py syncdb --noinput
	python manage.py migrate --noinput

# test:
# 	python manage.py test --noinput api cm provider web

coverage:
	coverage run manage.py test --noinput api cm provider web
	coverage html

test_client:
	python -m unittest discover client.tests

flake8:
	flake8

# container stuff

build:
	./make.sh build

server:
	./make.sh server

worker:
	./make.sh worker

shell:
	./make.sh shell

discover:
	./make.sh discover
	
syncdb:
	./make.sh syncdb

test:
	./make.sh test

clean:
	./make.sh clean
