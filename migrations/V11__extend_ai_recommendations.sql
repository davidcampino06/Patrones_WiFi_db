-- Generative recommendations (Claude) are longer than rule-based ones and record where they came from.
ALTER TABLE ai_predictions ALTER COLUMN recommendation TYPE VARCHAR(1500);

ALTER TABLE ai_predictions
    ADD COLUMN recommendation_source VARCHAR(10) NOT NULL DEFAULT 'RULES',
    ADD CONSTRAINT ck_ai_predictions_recommendation_source CHECK (recommendation_source IN ('RULES', 'CLAUDE'));
