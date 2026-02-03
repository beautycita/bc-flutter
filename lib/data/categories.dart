import 'package:flutter/material.dart';
import '../models/category.dart';

const List<ServiceCategory> allCategories = [
  // 💅 Uñas
  ServiceCategory(
    id: 'nails',
    nameEs: 'Uñas',
    icon: '💅',
    color: Color(0xFFE91E63),
    subcategories: [
      ServiceSubcategory(
        id: 'manicure',
        categoryId: 'nails',
        nameEs: 'Manicure',
        items: [
          ServiceItem(
            id: 'manicure_clasico',
            subcategoryId: 'manicure',
            nameEs: 'Clásico',
            serviceType: 'manicure_clasico',
          ),
          ServiceItem(
            id: 'manicure_gel',
            subcategoryId: 'manicure',
            nameEs: 'Gel',
            serviceType: 'manicure_gel',
          ),
          ServiceItem(
            id: 'manicure_frances',
            subcategoryId: 'manicure',
            nameEs: 'Francés',
            serviceType: 'manicure_frances',
          ),
          ServiceItem(
            id: 'manicure_dip_powder',
            subcategoryId: 'manicure',
            nameEs: 'Dip Powder',
            serviceType: 'manicure_dip_powder',
          ),
          ServiceItem(
            id: 'manicure_acrilico',
            subcategoryId: 'manicure',
            nameEs: 'Acrílico',
            serviceType: 'manicure_acrilico',
          ),
          ServiceItem(
            id: 'manicure_spa',
            subcategoryId: 'manicure',
            nameEs: 'Spa/Luxury',
            serviceType: 'manicure_spa',
          ),
          ServiceItem(
            id: 'manicure_japones',
            subcategoryId: 'manicure',
            nameEs: 'Japonés',
            serviceType: 'manicure_japones',
          ),
          ServiceItem(
            id: 'manicure_parafina',
            subcategoryId: 'manicure',
            nameEs: 'Parafina',
            serviceType: 'manicure_parafina',
          ),
          ServiceItem(
            id: 'manicure_ruso',
            subcategoryId: 'manicure',
            nameEs: 'Ruso',
            serviceType: 'manicure_ruso',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'pedicure',
        categoryId: 'nails',
        nameEs: 'Pedicure',
        items: [
          ServiceItem(
            id: 'pedicure_clasico',
            subcategoryId: 'pedicure',
            nameEs: 'Clásico',
            serviceType: 'pedicure_clasico',
          ),
          ServiceItem(
            id: 'pedicure_spa',
            subcategoryId: 'pedicure',
            nameEs: 'Spa/Luxury',
            serviceType: 'pedicure_spa',
          ),
          ServiceItem(
            id: 'pedicure_gel',
            subcategoryId: 'pedicure',
            nameEs: 'Gel',
            serviceType: 'pedicure_gel',
          ),
          ServiceItem(
            id: 'pedicure_medico',
            subcategoryId: 'pedicure',
            nameEs: 'Médico',
            serviceType: 'pedicure_medico',
          ),
          ServiceItem(
            id: 'pedicure_parafina',
            subcategoryId: 'pedicure',
            nameEs: 'Parafina',
            serviceType: 'pedicure_parafina',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'nail_art',
        categoryId: 'nails',
        nameEs: 'Nail Art',
      ),
      ServiceSubcategory(
        id: 'cambio_esmalte',
        categoryId: 'nails',
        nameEs: 'Cambio de Esmalte',
      ),
      ServiceSubcategory(
        id: 'reparacion',
        categoryId: 'nails',
        nameEs: 'Reparación',
      ),
      ServiceSubcategory(
        id: 'relleno',
        categoryId: 'nails',
        nameEs: 'Relleno',
      ),
      ServiceSubcategory(
        id: 'retiro',
        categoryId: 'nails',
        nameEs: 'Retiro',
      ),
    ],
  ),

  // ✂️ Cabello
  ServiceCategory(
    id: 'hair',
    nameEs: 'Cabello',
    icon: '✂️',
    color: Color(0xFF8D6E63),
    subcategories: [
      ServiceSubcategory(
        id: 'corte',
        categoryId: 'hair',
        nameEs: 'Corte',
        items: [
          ServiceItem(
            id: 'corte_mujer',
            subcategoryId: 'corte',
            nameEs: 'Mujer',
            serviceType: 'corte_mujer',
          ),
          ServiceItem(
            id: 'corte_hombre',
            subcategoryId: 'corte',
            nameEs: 'Hombre',
            serviceType: 'corte_hombre',
          ),
          ServiceItem(
            id: 'corte_nino',
            subcategoryId: 'corte',
            nameEs: 'Niño/a',
            serviceType: 'corte_nino',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'color',
        categoryId: 'hair',
        nameEs: 'Color',
        items: [
          ServiceItem(
            id: 'color_tinte_completo',
            subcategoryId: 'color',
            nameEs: 'Tinte Completo',
            serviceType: 'color_tinte_completo',
          ),
          ServiceItem(
            id: 'color_retoque_raiz',
            subcategoryId: 'color',
            nameEs: 'Retoque de Raíz',
            serviceType: 'color_retoque_raiz',
          ),
          ServiceItem(
            id: 'color_mechas',
            subcategoryId: 'color',
            nameEs: 'Mechas',
            serviceType: 'color_mechas',
          ),
          ServiceItem(
            id: 'color_balayage',
            subcategoryId: 'color',
            nameEs: 'Balayage',
            serviceType: 'color_balayage',
          ),
          ServiceItem(
            id: 'color_ombre',
            subcategoryId: 'color',
            nameEs: 'Ombré',
            serviceType: 'color_ombre',
          ),
          ServiceItem(
            id: 'color_correccion',
            subcategoryId: 'color',
            nameEs: 'Corrección',
            serviceType: 'color_correccion',
          ),
          ServiceItem(
            id: 'color_decoloracion',
            subcategoryId: 'color',
            nameEs: 'Decoloración',
            serviceType: 'color_decoloracion',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'tratamiento',
        categoryId: 'hair',
        nameEs: 'Tratamiento',
        items: [
          ServiceItem(
            id: 'tratamiento_keratina',
            subcategoryId: 'tratamiento',
            nameEs: 'Keratina',
            serviceType: 'tratamiento_keratina',
          ),
          ServiceItem(
            id: 'tratamiento_botox',
            subcategoryId: 'tratamiento',
            nameEs: 'Botox Capilar',
            serviceType: 'tratamiento_botox',
          ),
          ServiceItem(
            id: 'tratamiento_hidratacion',
            subcategoryId: 'tratamiento',
            nameEs: 'Hidratación',
            serviceType: 'tratamiento_hidratacion',
          ),
          ServiceItem(
            id: 'tratamiento_olaplex',
            subcategoryId: 'tratamiento',
            nameEs: 'Olaplex',
            serviceType: 'tratamiento_olaplex',
          ),
          ServiceItem(
            id: 'tratamiento_anticaida',
            subcategoryId: 'tratamiento',
            nameEs: 'Anticaída',
            serviceType: 'tratamiento_anticaida',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'peinado',
        categoryId: 'hair',
        nameEs: 'Peinado',
        items: [
          ServiceItem(
            id: 'peinado_blowout',
            subcategoryId: 'peinado',
            nameEs: 'Blowout',
            serviceType: 'peinado_blowout',
          ),
          ServiceItem(
            id: 'peinado_planchado',
            subcategoryId: 'peinado',
            nameEs: 'Planchado',
            serviceType: 'peinado_planchado',
          ),
          ServiceItem(
            id: 'peinado_ondas',
            subcategoryId: 'peinado',
            nameEs: 'Ondas',
            serviceType: 'peinado_ondas',
          ),
          ServiceItem(
            id: 'peinado_recogido',
            subcategoryId: 'peinado',
            nameEs: 'Recogido',
            serviceType: 'peinado_recogido',
          ),
          ServiceItem(
            id: 'peinado_trenzas',
            subcategoryId: 'peinado',
            nameEs: 'Trenzas',
            serviceType: 'peinado_trenzas',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'extensiones',
        categoryId: 'hair',
        nameEs: 'Extensiones',
        items: [
          ServiceItem(
            id: 'extensiones_clip',
            subcategoryId: 'extensiones',
            nameEs: 'Clip-In',
            serviceType: 'extensiones_clip',
          ),
          ServiceItem(
            id: 'extensiones_cosidas',
            subcategoryId: 'extensiones',
            nameEs: 'Cosidas',
            serviceType: 'extensiones_cosidas',
          ),
          ServiceItem(
            id: 'extensiones_fusion',
            subcategoryId: 'extensiones',
            nameEs: 'Fusión',
            serviceType: 'extensiones_fusion',
          ),
          ServiceItem(
            id: 'extensiones_cinta',
            subcategoryId: 'extensiones',
            nameEs: 'Cinta',
            serviceType: 'extensiones_cinta',
          ),
        ],
      ),
    ],
  ),

  // 👁️ Pestañas y Cejas
  ServiceCategory(
    id: 'lashes_brows',
    nameEs: 'Pestañas y Cejas',
    icon: '👁️',
    color: Color(0xFF9C27B0),
    subcategories: [
      ServiceSubcategory(
        id: 'pestanas',
        categoryId: 'lashes_brows',
        nameEs: 'Pestañas',
        items: [
          ServiceItem(
            id: 'pestanas_clasicas',
            subcategoryId: 'pestanas',
            nameEs: 'Clásicas',
            serviceType: 'pestanas_clasicas',
          ),
          ServiceItem(
            id: 'pestanas_hibridas',
            subcategoryId: 'pestanas',
            nameEs: 'Híbridas',
            serviceType: 'pestanas_hibridas',
          ),
          ServiceItem(
            id: 'pestanas_volumen',
            subcategoryId: 'pestanas',
            nameEs: 'Volumen',
            serviceType: 'pestanas_volumen',
          ),
          ServiceItem(
            id: 'pestanas_mega_volumen',
            subcategoryId: 'pestanas',
            nameEs: 'Mega Volumen',
            serviceType: 'pestanas_mega_volumen',
          ),
          ServiceItem(
            id: 'pestanas_lifting',
            subcategoryId: 'pestanas',
            nameEs: 'Lifting',
            serviceType: 'pestanas_lifting',
          ),
          ServiceItem(
            id: 'pestanas_tinte',
            subcategoryId: 'pestanas',
            nameEs: 'Tinte',
            serviceType: 'pestanas_tinte',
          ),
          ServiceItem(
            id: 'pestanas_relleno',
            subcategoryId: 'pestanas',
            nameEs: 'Relleno',
            serviceType: 'pestanas_relleno',
          ),
          ServiceItem(
            id: 'pestanas_retiro',
            subcategoryId: 'pestanas',
            nameEs: 'Retiro',
            serviceType: 'pestanas_retiro',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'cejas',
        categoryId: 'lashes_brows',
        nameEs: 'Cejas',
        items: [
          ServiceItem(
            id: 'cejas_diseno',
            subcategoryId: 'cejas',
            nameEs: 'Diseño',
            serviceType: 'cejas_diseno',
          ),
          ServiceItem(
            id: 'cejas_microblading',
            subcategoryId: 'cejas',
            nameEs: 'Microblading',
            serviceType: 'cejas_microblading',
          ),
          ServiceItem(
            id: 'cejas_micropigmentacion',
            subcategoryId: 'cejas',
            nameEs: 'Micropigmentación',
            serviceType: 'cejas_micropigmentacion',
          ),
          ServiceItem(
            id: 'cejas_laminado',
            subcategoryId: 'cejas',
            nameEs: 'Laminado',
            serviceType: 'cejas_laminado',
          ),
          ServiceItem(
            id: 'cejas_tinte',
            subcategoryId: 'cejas',
            nameEs: 'Tinte',
            serviceType: 'cejas_tinte',
          ),
          ServiceItem(
            id: 'cejas_henna',
            subcategoryId: 'cejas',
            nameEs: 'Henna',
            serviceType: 'cejas_henna',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'combo',
        categoryId: 'lashes_brows',
        nameEs: 'Combo',
      ),
    ],
  ),

  // 💄 Maquillaje
  ServiceCategory(
    id: 'makeup',
    nameEs: 'Maquillaje',
    icon: '💄',
    color: Color(0xFFFF5252),
    subcategories: [
      ServiceSubcategory(
        id: 'maquillaje_social',
        categoryId: 'makeup',
        nameEs: 'Social',
      ),
      ServiceSubcategory(
        id: 'maquillaje_evento',
        categoryId: 'makeup',
        nameEs: 'Evento',
      ),
      ServiceSubcategory(
        id: 'maquillaje_novia',
        categoryId: 'makeup',
        nameEs: 'Novia',
      ),
      ServiceSubcategory(
        id: 'maquillaje_xv',
        categoryId: 'makeup',
        nameEs: 'XV Años',
      ),
      ServiceSubcategory(
        id: 'maquillaje_editorial',
        categoryId: 'makeup',
        nameEs: 'Editorial',
      ),
      ServiceSubcategory(
        id: 'maquillaje_clase',
        categoryId: 'makeup',
        nameEs: 'Clase',
      ),
      ServiceSubcategory(
        id: 'maquillaje_prueba',
        categoryId: 'makeup',
        nameEs: 'Prueba',
      ),
    ],
  ),

  // 💆 Facial
  ServiceCategory(
    id: 'facial',
    nameEs: 'Facial',
    icon: '💆',
    color: Color(0xFF26A69A),
    subcategories: [
      ServiceSubcategory(
        id: 'limpieza',
        categoryId: 'facial',
        nameEs: 'Limpieza',
        items: [
          ServiceItem(
            id: 'limpieza_basica',
            subcategoryId: 'limpieza',
            nameEs: 'Básica',
            serviceType: 'limpieza_basica',
          ),
          ServiceItem(
            id: 'limpieza_profunda',
            subcategoryId: 'limpieza',
            nameEs: 'Profunda',
            serviceType: 'limpieza_profunda',
          ),
          ServiceItem(
            id: 'limpieza_hidrafacial',
            subcategoryId: 'limpieza',
            nameEs: 'Hidrafacial',
            serviceType: 'limpieza_hidrafacial',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'facial_antiedad',
        categoryId: 'facial',
        nameEs: 'Anti-Edad',
      ),
      ServiceSubcategory(
        id: 'facial_antiacne',
        categoryId: 'facial',
        nameEs: 'Anti-Acné',
      ),
      ServiceSubcategory(
        id: 'facial_microdermoabrasion',
        categoryId: 'facial',
        nameEs: 'Microdermoabrasión',
      ),
      ServiceSubcategory(
        id: 'facial_dermapen',
        categoryId: 'facial',
        nameEs: 'Dermapen',
      ),
      ServiceSubcategory(
        id: 'facial_peeling',
        categoryId: 'facial',
        nameEs: 'Peeling',
      ),
      ServiceSubcategory(
        id: 'facial_radiofrecuencia',
        categoryId: 'facial',
        nameEs: 'Radiofrecuencia',
      ),
      ServiceSubcategory(
        id: 'facial_led',
        categoryId: 'facial',
        nameEs: 'LED',
      ),
      ServiceSubcategory(
        id: 'facial_mascarilla',
        categoryId: 'facial',
        nameEs: 'Mascarilla',
      ),
    ],
  ),

  // 🧖 Cuerpo y Spa
  ServiceCategory(
    id: 'body_spa',
    nameEs: 'Cuerpo y Spa',
    icon: '🧖',
    color: Color(0xFF5C6BC0),
    subcategories: [
      ServiceSubcategory(
        id: 'masaje',
        categoryId: 'body_spa',
        nameEs: 'Masaje',
        items: [
          ServiceItem(
            id: 'masaje_relajante',
            subcategoryId: 'masaje',
            nameEs: 'Relajante',
            serviceType: 'masaje_relajante',
          ),
          ServiceItem(
            id: 'masaje_descontracturante',
            subcategoryId: 'masaje',
            nameEs: 'Descontracturante',
            serviceType: 'masaje_descontracturante',
          ),
          ServiceItem(
            id: 'masaje_piedras',
            subcategoryId: 'masaje',
            nameEs: 'Piedras Calientes',
            serviceType: 'masaje_piedras',
          ),
          ServiceItem(
            id: 'masaje_prenatal',
            subcategoryId: 'masaje',
            nameEs: 'Prenatal',
            serviceType: 'masaje_prenatal',
          ),
          ServiceItem(
            id: 'masaje_reflexologia',
            subcategoryId: 'masaje',
            nameEs: 'Reflexología',
            serviceType: 'masaje_reflexologia',
          ),
          ServiceItem(
            id: 'masaje_drenaje',
            subcategoryId: 'masaje',
            nameEs: 'Drenaje',
            serviceType: 'masaje_drenaje',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'depilacion',
        categoryId: 'body_spa',
        nameEs: 'Depilación',
        items: [
          ServiceItem(
            id: 'depilacion_cera',
            subcategoryId: 'depilacion',
            nameEs: 'Cera',
            serviceType: 'depilacion_cera',
          ),
          ServiceItem(
            id: 'depilacion_laser',
            subcategoryId: 'depilacion',
            nameEs: 'Láser',
            serviceType: 'depilacion_laser',
          ),
          ServiceItem(
            id: 'depilacion_hilo',
            subcategoryId: 'depilacion',
            nameEs: 'Hilo',
            serviceType: 'depilacion_hilo',
          ),
          ServiceItem(
            id: 'depilacion_sugaring',
            subcategoryId: 'depilacion',
            nameEs: 'Sugaring',
            serviceType: 'depilacion_sugaring',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'tratamiento_corporal',
        categoryId: 'body_spa',
        nameEs: 'Tratamiento Corporal',
        items: [
          ServiceItem(
            id: 'corporal_exfoliacion',
            subcategoryId: 'tratamiento_corporal',
            nameEs: 'Exfoliación',
            serviceType: 'corporal_exfoliacion',
          ),
          ServiceItem(
            id: 'corporal_envolvimiento',
            subcategoryId: 'tratamiento_corporal',
            nameEs: 'Envolvimiento',
            serviceType: 'corporal_envolvimiento',
          ),
          ServiceItem(
            id: 'corporal_radiofrecuencia',
            subcategoryId: 'tratamiento_corporal',
            nameEs: 'Radiofrecuencia',
            serviceType: 'corporal_radiofrecuencia',
          ),
          ServiceItem(
            id: 'corporal_cavitacion',
            subcategoryId: 'tratamiento_corporal',
            nameEs: 'Cavitación',
            serviceType: 'corporal_cavitacion',
          ),
          ServiceItem(
            id: 'corporal_mesoterapia',
            subcategoryId: 'tratamiento_corporal',
            nameEs: 'Mesoterapia',
            serviceType: 'corporal_mesoterapia',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'bronceado',
        categoryId: 'body_spa',
        nameEs: 'Bronceado',
        items: [
          ServiceItem(
            id: 'bronceado_spray',
            subcategoryId: 'bronceado',
            nameEs: 'Spray',
            serviceType: 'bronceado_spray',
          ),
          ServiceItem(
            id: 'bronceado_cama',
            subcategoryId: 'bronceado',
            nameEs: 'Cama',
            serviceType: 'bronceado_cama',
          ),
        ],
      ),
    ],
  ),

  // 🧴 Cuidado Especializado
  ServiceCategory(
    id: 'specialized',
    nameEs: 'Cuidado Especializado',
    icon: '🧴',
    color: Color(0xFFFFA726),
    subcategories: [
      ServiceSubcategory(
        id: 'micropigmentacion_labios',
        categoryId: 'specialized',
        nameEs: 'Micropigmentación Labios',
      ),
      ServiceSubcategory(
        id: 'remocion_tatuajes',
        categoryId: 'specialized',
        nameEs: 'Remoción Tatuajes',
      ),
      ServiceSubcategory(
        id: 'blanqueamiento_dental',
        categoryId: 'specialized',
        nameEs: 'Blanqueamiento Dental',
      ),
      ServiceSubcategory(
        id: 'consulta_virtual',
        categoryId: 'specialized',
        nameEs: 'Consulta Virtual',
      ),
    ],
  ),

  // 💈 Barbería
  ServiceCategory(
    id: 'barberia',
    nameEs: 'Barbería',
    icon: '💈',
    color: Color(0xFF37474F),
    subcategories: [
      ServiceSubcategory(
        id: 'barberia_corte_hombre',
        categoryId: 'barberia',
        nameEs: 'Corte Hombre',
      ),
      ServiceSubcategory(
        id: 'barberia_corte_barba',
        categoryId: 'barberia',
        nameEs: 'Corte + Barba',
        items: [
          ServiceItem(
            id: 'barberia_corte_barba_clasico',
            subcategoryId: 'barberia_corte_barba',
            nameEs: 'Clásico',
            serviceType: 'barberia_corte_barba',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'barberia_afeitado',
        categoryId: 'barberia',
        nameEs: 'Afeitado Clásico',
        items: [
          ServiceItem(
            id: 'barberia_afeitado_clasico',
            subcategoryId: 'barberia_afeitado',
            nameEs: 'Afeitado Clásico',
            serviceType: 'barberia_afeitado',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'barberia_diseno',
        categoryId: 'barberia',
        nameEs: 'Diseño Barba',
        items: [
          ServiceItem(
            id: 'barberia_diseno_barba',
            subcategoryId: 'barberia_diseno',
            nameEs: 'Diseño Barba',
            serviceType: 'barberia_diseno',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'barberia_tratamiento',
        categoryId: 'barberia',
        nameEs: 'Tratamiento Barba',
        items: [
          ServiceItem(
            id: 'barberia_tratamiento_barba',
            subcategoryId: 'barberia_tratamiento',
            nameEs: 'Tratamiento Barba',
            serviceType: 'barberia_tratamiento',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'barberia_fade',
        categoryId: 'barberia',
        nameEs: 'Fade/Degradado',
      ),
    ],
  ),
];
