import swaggerUi from 'swagger-ui-express';

export const openApiSpec = {
  openapi: '3.0.3',
  info: {
    title: 'RAK TAK CASH API',
    version: '1.0.0',
    description: 'Comptes, portefeuilles Lightning et séquestre bilatéral. Hackathon Code & Chain Dakar 2026.',
  },
  servers: [{ url: '/', description: 'Serveur courant' }],
  components: {
    securitySchemes: {
      bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
    },
  },
  paths: {
    '/health': {
      get: {
        tags: ['Système'],
        summary: 'Santé du serveur et de PostgreSQL',
        responses: { 200: { description: 'Serveur et base disponibles' } },
      },
    },
    '/auth/register': {
      post: {
        tags: ['Comptes'],
        summary: 'Créer un compte et son portefeuille',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['phone', 'password'],
                properties: {
                  phone: { type: 'string', example: '771234567' },
                  password: { type: 'string', example: 'secret123' },
                  fullName: { type: 'string', example: 'Awa Ndiaye' },
                },
              },
            },
          },
        },
        responses: { 201: { description: 'Compte créé' }, 409: { description: 'Numéro déjà inscrit' } },
      },
    },
    '/auth/login': {
      post: {
        tags: ['Comptes'],
        summary: 'Connexion par téléphone et mot de passe',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['phone', 'password'],
                properties: {
                  phone: { type: 'string', example: '771234567' },
                  password: { type: 'string' },
                },
              },
            },
          },
        },
        responses: { 200: { description: 'JWT renvoyé' }, 401: { description: 'Identifiants invalides' } },
      },
    },
    '/auth/me': {
      get: {
        tags: ['Comptes'],
        summary: 'Profil du compte connecté',
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: 'Profil' }, 401: { description: 'Non connecté' } },
      },
    },
    '/wallet': {
      get: {
        tags: ['Portefeuille'],
        summary: 'Portefeuille et transactions du compte connecté',
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: 'Solde disponible, séquestre et historique' } },
      },
    },
    '/invoice': {
      post: {
        tags: ['Factures'],
        summary: 'Créer une facture Lightning pour le commerçant connecté',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['amount'],
                properties: {
                  amount: { type: 'integer', example: 150 },
                  description: { type: 'string', example: 'Chaussures Cuir Sandaga' },
                  isEscrow: { type: 'boolean', example: true },
                },
              },
            },
          },
        },
        responses: { 200: { description: 'Facture BOLT11 créée' } },
      },
    },
    '/invoice/{reference}/status': {
      get: {
        tags: ['Factures'],
        summary: 'Statut public d’une facture (réconciliation Bitnob)',
        parameters: [{ name: 'reference', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'État de la facture' }, 404: { description: 'Introuvable' } },
      },
    },
    '/invoice/{reference}/pay': {
      post: {
        tags: ['Factures'],
        summary: 'Règlement démo : consigne les fonds sur le portefeuille du vendeur',
        parameters: [{ name: 'reference', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Facture réglée' } },
      },
    },
    '/invoice/{reference}/release': {
      post: {
        tags: ['Séquestre'],
        summary: 'Débloquer le séquestre avec le code du client',
        security: [{ bearerAuth: [] }],
        parameters: [{ name: 'reference', in: 'path', required: true, schema: { type: 'string' } }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['code'],
                properties: { code: { type: 'string', example: '7C23' } },
              },
            },
          },
        },
        responses: { 200: { description: 'Fonds versés sur le solde disponible' }, 400: { description: 'Code invalide' } },
      },
    },
    '/pay/{reference}': {
      get: {
        tags: ['Acheteur'],
        summary: 'Page web acheteur (QR, deep link, code secret)',
        parameters: [{ name: 'reference', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Page HTML' } },
      },
    },
    '/webhook': {
      post: {
        tags: ['Bitnob'],
        summary: 'Webhook Bitnob signé HMAC',
        responses: { 200: { description: 'Accepté' }, 401: { description: 'Signature invalide' } },
      },
    },
    '/admin/api/overview': {
      get: {
        tags: ['Admin'],
        summary: 'Indicateurs globaux',
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: 'Statistiques' }, 403: { description: 'Admin requis' } },
      },
    },
    '/admin/api/users': {
      get: {
        tags: ['Admin'],
        summary: 'Liste des comptes et portefeuilles',
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: 'Utilisateurs' } },
      },
    },
    '/admin/api/users/{id}/status': {
      post: {
        tags: ['Admin'],
        summary: 'Activer ou suspendre un compte',
        security: [{ bearerAuth: [] }],
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: { status: { type: 'string', enum: ['active', 'suspended'] } },
              },
            },
          },
        },
        responses: { 200: { description: 'Statut mis à jour' } },
      },
    },
    '/admin/api/users/{id}/credit': {
      post: {
        tags: ['Admin'],
        summary: 'Créditer ou débiter le portefeuille d’un compte',
        security: [{ bearerAuth: [] }],
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['sats'],
                properties: {
                  sats: { type: 'integer', example: 1000 },
                  note: { type: 'string', example: 'Solde de démonstration' },
                },
              },
            },
          },
        },
        responses: { 200: { description: 'Portefeuille ajusté' } },
      },
    },
    '/admin/api/invoices': {
      get: {
        tags: ['Admin'],
        summary: 'Toutes les factures',
        security: [{ bearerAuth: [] }],
        responses: { 200: { description: 'Factures' } },
      },
    },
  },
};

export function mountDocs(app) {
  app.get('/openapi.json', (req, res) => res.json(openApiSpec));
  app.use('/docs', swaggerUi.serve, swaggerUi.setup(openApiSpec, { customSiteTitle: 'RAK TAK CASH API' }));
}
