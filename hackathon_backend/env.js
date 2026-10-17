import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Charge toujours hackathon_backend/.env, quel que soit le dossier de lancement.
// Les variables déjà définies (Render, shell) ne sont pas écrasées.
dotenv.config({ path: path.join(__dirname, '.env') });
