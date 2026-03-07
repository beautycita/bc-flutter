// Portfolio shared JS — data fetch, hydration, before/after slider, adaptive sections
// Used by all 5 portfolio themes. Loaded via <script src="shared.js"></script>

(function () {
  'use strict';

  var SUPABASE_URL = 'https://beautycita.com/supabase';
  var API_URL = SUPABASE_URL + '/functions/v1/portfolio-public';
  var ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjE4OTM0NTYwMDB9.rz0oLwpK6HMsRI3PStAW3K1gl79d6z1PqqW8lvCtF9Q';

  // Extract slug from URL: /s/salon-slug or /portfolio/preview?slug=x
  var path = window.location.pathname;
  var slug = path.split('/s/')[1];
  if (slug) slug = slug.split('/')[0].split('?')[0];
  if (!slug) slug = new URLSearchParams(window.location.search).get('slug');

  var staffFilter = new URLSearchParams(window.location.search).get('staff');

  if (!slug) {
    showError('Portafolio no encontrado');
    return;
  }

  fetch(API_URL + '?slug=' + encodeURIComponent(slug), {
    headers: { 'apikey': ANON_KEY }
  })
    .then(function (r) {
      if (r.status === 404) throw new Error('not_found');
      if (!r.ok) throw new Error('server_error');
      return r.json();
    })
    .then(function (data) {
      if (data.error) throw new Error(data.error);
      hydrate(data, staffFilter);
    })
    .catch(function (err) {
      if (err.message === 'not_found' || err.message === 'Portfolio not found or not public') {
        showNotAvailable();
      } else {
        showError('Error cargando portafolio');
        console.error('Portfolio fetch error:', err);
      }
    });

  function showNotAvailable() {
    var el = document.querySelector('[data-portfolio="loading"]');
    if (el) el.style.display = 'none';
    var na = document.querySelector('[data-portfolio="not-available"]');
    if (na) {
      na.style.display = 'flex';
    } else {
      document.body.innerHTML = '<div style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:system-ui;color:#666;text-align:center;padding:2rem"><div><h2>Este portafolio no est\u00e1 disponible</h2><p>El sal\u00f3n a\u00fan no ha publicado su portafolio.</p><a href="https://beautycita.com" style="color:#c2185b;text-decoration:none">Ir a BeautyCita</a></div></div>';
    }
  }

  function showError(msg) {
    var el = document.querySelector('[data-portfolio="loading"]');
    if (el) el.style.display = 'none';
    var err = document.querySelector('[data-portfolio="error"]');
    if (err) {
      err.textContent = msg;
      err.style.display = 'block';
    }
  }

  function hydrate(data, staffFilter) {
    var salon = data.salon || {};
    var team = data.team || [];
    var photos = data.photos || [];
    var services = data.services || [];
    var reviews = data.reviews || [];

    // Hide loading
    var loading = document.querySelector('[data-portfolio="loading"]');
    if (loading) loading.style.display = 'none';

    // Show main content
    var main = document.querySelector('[data-portfolio="content"]');
    if (main) main.style.display = '';

    // --- Salon info ---
    setText('salon-name', salon.name);
    setText('salon-tagline', salon.tagline);
    setText('salon-bio', salon.bio);
    setText('salon-address', [salon.address, salon.city, salon.state].filter(Boolean).join(', '));
    setText('salon-phone', salon.phone);
    setText('salon-rating', salon.average_rating ? parseFloat(salon.average_rating).toFixed(1) : null);
    setText('salon-review-count', salon.total_reviews ? salon.total_reviews + ' rese\u00f1as' : null);

    setImage('salon-photo', salon.photo_url);

    setLink('salon-whatsapp', salon.whatsapp ? 'https://wa.me/' + salon.whatsapp.replace(/\D/g, '') : null);
    setLink('salon-website', salon.website);
    setLink('salon-instagram', salon.instagram_handle ? 'https://instagram.com/' + salon.instagram_handle : null);
    setLink('salon-facebook', salon.facebook_url);

    // --- Hours ---
    var hoursEl = document.querySelector('[data-portfolio="salon-hours"]');
    if (hoursEl && salon.hours) {
      var days = ['Lunes', 'Martes', 'Mi\u00e9rcoles', 'Jueves', 'Viernes', 'S\u00e1bado', 'Domingo'];
      var keys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      var html = '';
      for (var i = 0; i < keys.length; i++) {
        var day = salon.hours[keys[i]];
        if (day && day.open) {
          html += '<div class="hours-row"><span>' + days[i] + '</span><span>' + day.open + ' - ' + day.close + '</span></div>';
        } else {
          html += '<div class="hours-row closed"><span>' + days[i] + '</span><span>Cerrado</span></div>';
        }
      }
      hoursEl.innerHTML = html;
    }
    hideIfEmpty('section-hours', salon.hours);

    // --- Team ---
    var teamContainer = document.querySelector('[data-portfolio="team"]');
    if (teamContainer && team.length > 0) {
      var filteredTeam = staffFilter
        ? team.filter(function (s) {
          var name = (s.first_name + '-' + (s.last_name || '')).toLowerCase().replace(/\s+/g, '-');
          return name === staffFilter.toLowerCase() || s.id === staffFilter;
        })
        : team;

      if (filteredTeam.length === 0) filteredTeam = team;

      teamContainer.innerHTML = filteredTeam.map(function (s) {
        var stars = s.average_rating ? renderStars(parseFloat(s.average_rating)) : '';
        var specs = (s.specialties || []).map(function (sp) { return '<span class="tag">' + esc(sp) + '</span>'; }).join('');
        var stats = [];
        if (s.avg_services_week) stats.push(s.avg_services_week + ' servicios/semana');
        if (s.total_reviews) stats.push(s.total_reviews + ' rese\u00f1as');
        if (s.photo_count) stats.push(s.photo_count + ' fotos');

        return '<div class="team-card">' +
          (s.avatar_url ? '<img src="' + esc(s.avatar_url) + '" alt="' + esc(s.first_name) + '" class="team-avatar" loading="lazy">' : '<div class="team-avatar placeholder">' + esc(s.first_name.charAt(0)) + '</div>') +
          '<div class="team-info">' +
          '<h3>' + esc(s.first_name) + (s.last_name ? ' ' + esc(s.last_name) : '') + '</h3>' +
          (s.bio ? '<p class="team-bio">' + esc(s.bio) + '</p>' : '') +
          (specs ? '<div class="tags">' + specs + '</div>' : '') +
          (stars ? '<div class="team-rating">' + stars + '</div>' : '') +
          (stats.length ? '<div class="team-stats">' + stats.join(' &middot; ') + '</div>' : '') +
          '</div></div>';
      }).join('');
    }
    hideIfEmpty('section-team', team.length > 0);

    // --- Photos ---
    var photosContainer = document.querySelector('[data-portfolio="photos"]');
    if (photosContainer && photos.length > 0) {
      var filteredPhotos = photos;
      if (staffFilter) {
        var staffMatch = team.find(function (s) {
          var name = (s.first_name + '-' + (s.last_name || '')).toLowerCase().replace(/\s+/g, '-');
          return name === staffFilter.toLowerCase() || s.id === staffFilter;
        });
        if (staffMatch) {
          filteredPhotos = photos.filter(function (p) { return p.staff_id === staffMatch.id; });
          if (filteredPhotos.length === 0) filteredPhotos = photos;
        }
      }

      photosContainer.innerHTML = filteredPhotos.map(function (p) {
        if (p.photo_type === 'before_after' && p.before_url) {
          return '<div class="photo-card before-after">' +
            '<div class="ba-slider" data-before="' + esc(p.before_url) + '" data-after="' + esc(p.after_url) + '">' +
            '<img src="' + esc(p.after_url) + '" alt="Despu\u00e9s" class="ba-after" loading="lazy">' +
            '<div class="ba-before-wrap"><img src="' + esc(p.before_url) + '" alt="Antes" class="ba-before" loading="lazy"></div>' +
            '<input type="range" min="0" max="100" value="50" class="ba-range" aria-label="Antes y despu\u00e9s">' +
            '<div class="ba-labels"><span>Antes</span><span>Despu\u00e9s</span></div>' +
            '</div>' +
            (p.caption ? '<p class="photo-caption">' + esc(p.caption) + '</p>' : '') +
            (p.service_category ? '<span class="tag">' + esc(p.service_category) + '</span>' : '') +
            '</div>';
        }
        return '<div class="photo-card">' +
          '<img src="' + esc(p.after_url) + '" alt="' + esc(p.caption || 'Portafolio') + '" loading="lazy">' +
          (p.caption ? '<p class="photo-caption">' + esc(p.caption) + '</p>' : '') +
          (p.service_category ? '<span class="tag">' + esc(p.service_category) + '</span>' : '') +
          '</div>';
      }).join('');

      // Initialize before/after sliders
      initSliders();
    }
    hideIfEmpty('section-photos', photos.length > 0);

    // --- Services ---
    var servicesContainer = document.querySelector('[data-portfolio="services"]');
    if (servicesContainer && services.length > 0) {
      var byCategory = {};
      services.forEach(function (s) {
        var cat = s.category || 'Servicios';
        if (!byCategory[cat]) byCategory[cat] = [];
        byCategory[cat].push(s);
      });

      var html = '';
      Object.keys(byCategory).forEach(function (cat) {
        html += '<div class="service-category"><h3>' + esc(cat) + '</h3>';
        byCategory[cat].forEach(function (s) {
          html += '<div class="service-row">' +
            '<span class="service-name">' + esc(s.name) + '</span>' +
            '<span class="service-details">' +
            (s.price ? '$' + parseFloat(s.price).toFixed(0) + ' MXN' : '') +
            (s.duration_minutes ? ' &middot; ' + s.duration_minutes + ' min' : '') +
            '</span></div>';
        });
        html += '</div>';
      });
      servicesContainer.innerHTML = html;
    }
    hideIfEmpty('section-services', services.length > 0);

    // --- Reviews ---
    var reviewsContainer = document.querySelector('[data-portfolio="reviews"]');
    if (reviewsContainer && reviews.length > 0) {
      reviewsContainer.innerHTML = reviews.slice(0, 20).map(function (r) {
        return '<div class="review-card">' +
          '<div class="review-header">' +
          '<span class="review-author">' + esc(r.client_name) + '</span>' +
          '<span class="review-stars">' + renderStars(r.rating) + '</span>' +
          '</div>' +
          (r.comment ? '<p class="review-text">' + esc(r.comment) + '</p>' : '') +
          '<span class="review-date">' + formatDate(r.created_at) + '</span>' +
          '</div>';
      }).join('');
    }
    hideIfEmpty('section-reviews', reviews.length > 0);

    // --- Map ---
    var mapEl = document.querySelector('[data-portfolio="map"]');
    if (mapEl && salon.lat && salon.lng) {
      mapEl.innerHTML = '<iframe src="https://www.openstreetmap.org/export/embed.html?bbox=' +
        (salon.lng - 0.005) + ',' + (salon.lat - 0.003) + ',' + (salon.lng + 0.005) + ',' + (salon.lat + 0.003) +
        '&layer=mapnik&marker=' + salon.lat + ',' + salon.lng +
        '" width="100%" height="300" style="border:0;border-radius:12px" loading="lazy"></iframe>';
    }
    hideIfEmpty('section-map', salon.lat && salon.lng);

    // --- OG meta ---
    setMeta('og:title', salon.name ? salon.name + ' | Portafolio' : 'Portafolio');
    setMeta('og:description', salon.tagline || salon.bio || 'Portafolio profesional');
    if (salon.photo_url) setMeta('og:image', salon.photo_url);
    setMeta('og:url', window.location.href);
  }

  // --- Helpers ---
  function setText(key, value) {
    var els = document.querySelectorAll('[data-portfolio="' + key + '"]');
    for (var i = 0; i < els.length; i++) {
      if (value) {
        els[i].textContent = value;
      } else {
        els[i].style.display = 'none';
      }
    }
  }

  function setImage(key, url) {
    var els = document.querySelectorAll('[data-portfolio="' + key + '"]');
    for (var i = 0; i < els.length; i++) {
      if (url) {
        els[i].src = url;
        els[i].style.display = '';
      } else {
        els[i].style.display = 'none';
      }
    }
  }

  function setLink(key, url) {
    var els = document.querySelectorAll('[data-portfolio="' + key + '"]');
    for (var i = 0; i < els.length; i++) {
      if (url) {
        els[i].href = url;
        els[i].style.display = '';
      } else {
        els[i].style.display = 'none';
      }
    }
  }

  function setMeta(property, content) {
    if (!content) return;
    var el = document.querySelector('meta[property="' + property + '"]');
    if (el) {
      el.setAttribute('content', content);
    } else {
      var meta = document.createElement('meta');
      meta.setAttribute('property', property);
      meta.setAttribute('content', content);
      document.head.appendChild(meta);
    }
  }

  function hideIfEmpty(sectionId, hasData) {
    var el = document.querySelector('[data-section="' + sectionId + '"]');
    if (el && !hasData) el.style.display = 'none';
  }

  function renderStars(rating) {
    var full = Math.floor(rating);
    var half = rating - full >= 0.25 && rating - full < 0.75;
    var html = '';
    for (var i = 0; i < full; i++) html += '\u2605';
    if (half) { html += '\u00bd'; full++; }
    for (var j = full + (half ? 0 : 0); j < 5; j++) html += '\u2606';
    return html;
  }

  function formatDate(iso) {
    if (!iso) return '';
    var d = new Date(iso);
    var months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return d.getDate() + ' ' + months[d.getMonth()] + ' ' + d.getFullYear();
  }

  function esc(str) {
    if (!str) return '';
    var div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  function initSliders() {
    var sliders = document.querySelectorAll('.ba-range');
    for (var i = 0; i < sliders.length; i++) {
      (function (slider) {
        var wrap = slider.parentElement.querySelector('.ba-before-wrap');
        slider.addEventListener('input', function () {
          wrap.style.width = slider.value + '%';
        });
        wrap.style.width = '50%';
      })(sliders[i]);
    }
  }
})();
