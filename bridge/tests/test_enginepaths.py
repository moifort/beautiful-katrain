"""Le bundle impose ses chemins moteur ; hors bundle, rien ne change."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from enginepaths import bundle_engine_overrides


def test_no_variables_means_no_override():
    assert bundle_engine_overrides({}) == {}


def test_each_variable_maps_to_its_katrain_key():
    overrides = bundle_engine_overrides(
        {
            "MOYO_KATAGO": "/App/Helpers/katago",
            "MOYO_MODEL": "/App/Resources/models/play.bin.gz",
            "MOYO_HUMAN_MODEL": "/App/Resources/models/human.bin.gz",
            "MOYO_CONFIG": "/App/Resources/analysis_config.cfg",
        }
    )
    assert overrides == {
        "katago": "/App/Helpers/katago",
        "model": "/App/Resources/models/play.bin.gz",
        "humanlike_model": "/App/Resources/models/human.bin.gz",
        "config": "/App/Resources/analysis_config.cfg",
    }


def test_a_partial_environment_overrides_only_what_it_names():
    assert bundle_engine_overrides({"MOYO_KATAGO": "/App/Helpers/katago"}) == {
        "katago": "/App/Helpers/katago"
    }


def test_empty_values_are_ignored_rather_than_overriding_with_nothing():
    # Une variable vide est le cas d'un lancement de développement où le script
    # exporte la variable sans la renseigner : elle ne doit pas effacer la config.
    assert bundle_engine_overrides({"MOYO_KATAGO": "", "MOYO_MODEL": "/m.bin.gz"}) == {
        "model": "/m.bin.gz"
    }
